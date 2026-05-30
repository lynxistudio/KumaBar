import Foundation

struct KumaManagementClient: Sendable {
    enum ClientError: LocalizedError {
        case invalidServerURL
        case invalidWebsiteURL
        case missingManagementCredentials
        case missingManagementLogin
        case connectionFailed
        case timedOut
        case invalidResponse
        case authenticationFailed(String)
        case twoFactorAuthenticationUnsupported
        case addFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidServerURL:
                "The configured Uptime Kuma URL is invalid."
            case .invalidWebsiteURL:
                "Enter a valid website URL, including http:// or https://."
            case .missingManagementCredentials:
                "Enter your Uptime Kuma username and password to add a website."
            case .missingManagementLogin:
                "Save your Uptime Kuma management login in Settings before adding a website."
            case .connectionFailed:
                "Could not connect to the Uptime Kuma management socket."
            case .timedOut:
                "The Uptime Kuma management request timed out."
            case .invalidResponse:
                "Uptime Kuma returned an unexpected management response."
            case .authenticationFailed(let message):
                "Uptime Kuma login failed: \(message)"
            case .twoFactorAuthenticationUnsupported:
                "This account requires two-factor authentication. Add the monitor in the Uptime Kuma dashboard."
            case .addFailed(let message):
                "Could not add the website: \(message)"
            }
        }
    }

    func login(credentials: KumaManagementCredentials) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                let socket = try await openSocket(baseURL: credentials.baseURL)
                defer { socket.close() }
                let login = try await emit(
                    "login",
                    payload: [
                        "username": credentials.username,
                        "password": credentials.password
                    ],
                    acknowledgementID: 1,
                    to: socket.task
                )
                if login["tokenRequired"] as? Bool == true {
                    throw ClientError.twoFactorAuthenticationUnsupported
                }
                guard login["ok"] as? Bool == true,
                      let token = login["token"] as? String else {
                    throw ClientError.authenticationFailed(login["msg"] as? String ?? "incorrect username or password")
                }
                return token
            }
            group.addTask {
                try await Task.sleep(for: .seconds(15))
                throw ClientError.timedOut
            }
            guard let token = try await group.next() else {
                throw ClientError.connectionFailed
            }
            group.cancelAll()
            return token
        }
    }

    func addWebsite(baseURL: URL, managementToken: String, draft: AddWebsiteDraft) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await performAddWebsite(
                    baseURL: baseURL,
                    managementToken: managementToken,
                    draft: draft
                )
            }
            group.addTask {
                try await Task.sleep(for: .seconds(15))
                throw ClientError.timedOut
            }
            try await group.next()
            group.cancelAll()
        }
    }

    private func performAddWebsite(
        baseURL: URL,
        managementToken: String,
        draft: AddWebsiteDraft
    ) async throws {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = draft.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let websiteURL = URL(string: trimmedURL),
              let scheme = websiteURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              websiteURL.host != nil else {
            throw ClientError.invalidWebsiteURL
        }
        let socket = try await openSocket(baseURL: baseURL)
        defer { socket.close() }

        let login = try await emit(
            "loginByToken",
            payload: managementToken,
            acknowledgementID: 1,
            to: socket.task
        )
        guard login["ok"] as? Bool == true else {
            throw ClientError.authenticationFailed("saved login expired. Save it again in Settings.")
        }

        let addResponse = try await emit(
            "add",
            payload: Self.monitorPayload(
                name: trimmedName.isEmpty ? websiteURL.host ?? trimmedURL : trimmedName,
                url: trimmedURL,
                interval: draft.interval
            ),
            acknowledgementID: 2,
            to: socket.task
        )
        guard addResponse["ok"] as? Bool == true else {
            throw ClientError.addFailed(addResponse["msg"] as? String ?? "unknown server error")
        }
        RuntimeLog.write("management socket acknowledged add website")
    }

    private struct ConnectedSocket: @unchecked Sendable {
        let session: URLSession
        let task: URLSessionWebSocketTask

        func close() {
            task.cancel(with: .normalClosure, reason: nil)
            session.invalidateAndCancel()
        }
    }

    private func openSocket(baseURL: URL) async throws -> ConnectedSocket {
        guard let socketURL = Self.socketURL(for: baseURL) else {
            throw ClientError.invalidServerURL
        }
        let session = URLSession(configuration: .ephemeral)
        let task = session.webSocketTask(with: socketURL)
        task.resume()

        guard try await receivePacket(from: task, matching: { $0.hasPrefix("0") }) != nil else {
            throw ClientError.connectionFailed
        }
        try await task.send(.string("40"))
        guard try await receivePacket(from: task, matching: { $0.hasPrefix("40") }) != nil else {
            throw ClientError.connectionFailed
        }
        return ConnectedSocket(session: session, task: task)
    }

    static func socketURL(for baseURL: URL) -> URL? {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("socket.io/"),
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }
        switch components.scheme?.lowercased() {
        case "http": components.scheme = "ws"
        case "https": components.scheme = "wss"
        default: return nil
        }
        if !components.path.hasSuffix("/") {
            components.path += "/"
        }
        components.queryItems = [
            URLQueryItem(name: "EIO", value: "4"),
            URLQueryItem(name: "transport", value: "websocket")
        ]
        return components.url
    }

    static func monitorPayload(name: String, url: String, interval: Int) -> [String: Any] {
        [
            "type": "http",
            "name": name,
            "url": url,
            "method": "GET",
            "interval": interval,
            "retryInterval": interval,
            "maxretries": 0,
            "notificationIDList": [:],
            "upsideDown": false,
            "maxredirects": 10,
            "accepted_statuscodes": ["200-299"]
        ]
    }

    private func emit(
        _ event: String,
        payload: Any,
        acknowledgementID: Int,
        to socket: URLSessionWebSocketTask
    ) async throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: [event, payload])
        guard let json = String(data: data, encoding: .utf8) else {
            throw ClientError.invalidResponse
        }
        try await socket.send(.string("42\(acknowledgementID)\(json)"))

        let prefix = "43\(acknowledgementID)"
        guard let response = try await receivePacket(
            from: socket,
            matching: { $0.hasPrefix(prefix) }
        ) else {
            throw ClientError.invalidResponse
        }
        let payloadText = String(response.dropFirst(prefix.count))
        guard let payloadData = payloadText.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: payloadData) as? [Any],
              let object = array.first as? [String: Any] else {
            throw ClientError.invalidResponse
        }
        return object
    }

    private func receivePacket(
        from socket: URLSessionWebSocketTask,
        matching predicate: (String) -> Bool
    ) async throws -> String? {
        while true {
            let message = try await socket.receive()
            let text: String
            switch message {
            case .string(let value):
                text = value
            case .data(let data):
                text = String(decoding: data, as: UTF8.self)
            @unknown default:
                throw ClientError.invalidResponse
            }
            if text == "2" {
                try await socket.send(.string("3"))
            } else if predicate(text) {
                return text
            }
        }
    }
}
