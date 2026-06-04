import Foundation

protocol MonitorProviding: Sendable {
    func fetchMonitors(credentials: KumaCredentials) async throws -> [MonitorSnapshot]
}

struct KumaMetricsClient: MonitorProviding {
    enum ClientError: LocalizedError {
        case invalidResponse
        case authenticationFailed
        case serverError(Int)
        case invalidMetrics

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Uptime Kuma returned an invalid response."
            case .authenticationFailed: "Authentication failed. Check the URL and credentials."
            case .serverError(let status): "Uptime Kuma returned HTTP \(status)."
            case .invalidMetrics: "No monitor metrics were found. Check the Uptime Kuma URL and API access."
            }
        }
    }

    func fetchMonitors(credentials: KumaCredentials) async throws -> [MonitorSnapshot] {
        let session = Self.makeSession()
        defer { session.invalidateAndCancel() }
        let metricsURL = Self.metricsURL(for: credentials.baseURL)
        var request = URLRequest(url: metricsURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 15
        request.setValue(credentials.authorizationValue, forHTTPHeaderField: "Authorization")
        request.setValue("close", forHTTPHeaderField: "Connection")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw ClientError.authenticationFailed
        default:
            throw ClientError.serverError(httpResponse.statusCode)
        }

        let metrics = String(decoding: data, as: UTF8.self)
        let monitors = MetricsParser.parse(metrics, fetchedAt: Date())
        guard !monitors.isEmpty else {
            throw ClientError.invalidMetrics
        }
        return monitors
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.httpAdditionalHeaders = ["Accept": "text/plain"]
        return URLSession(configuration: configuration)
    }

    static func metricsURL(for baseURL: URL) -> URL {
        baseURL.appendingPathComponent("metrics")
    }
}

enum MetricsParser {
    private struct PartialMonitor {
        var name = ""
        var type = ""
        var target: String?
        var state = MonitorState.unknown
        var ping: Double?
        var sslDaysRemaining: Double?
    }

    static func parse(_ metrics: String, fetchedAt: Date) -> [MonitorSnapshot] {
        var partials: [String: PartialMonitor] = [:]

        for line in metrics.split(whereSeparator: \.isNewline) {
            guard !line.hasPrefix("#"),
                  let sample = parseSample(String(line)),
                  let id = monitorID(from: sample.labels) else {
                continue
            }

            var monitor = partials[id] ?? PartialMonitor()
            monitor.name = sample.labels["monitor_name"] ?? sample.labels["monitor"] ?? monitor.name
            monitor.type = sample.labels["monitor_type"] ?? sample.labels["type"] ?? monitor.type
            monitor.target = sample.labels["monitor_url"]
                ?? sample.labels["url"]
                ?? sample.labels["monitor_hostname"]
                ?? sample.labels["hostname"]
                ?? monitor.target

            switch sample.name {
            case "monitor_status":
                monitor.state = MonitorState(rawValue: Int(sample.value)) ?? .unknown
            case "monitor_response_time":
                monitor.ping = sample.value
            case "monitor_cert_days_remaining":
                monitor.sslDaysRemaining = sample.value
            default:
                break
            }
            partials[id] = monitor
        }

        return partials.compactMap { id, monitor in
            guard !monitor.name.isEmpty else { return nil }
            return MonitorSnapshot(
                id: id,
                name: monitor.name,
                type: monitor.type,
                target: monitor.target,
                state: monitor.state,
                responseTimeMilliseconds: monitor.ping,
                sslDaysRemaining: monitor.sslDaysRemaining,
                lastCheckTime: fetchedAt
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func monitorID(from labels: [String: String]) -> String? {
        labels["monitor_id"] ?? labels["id"] ?? labels["monitor_name"] ?? labels["monitor"]
    }

    private static func parseSample(_ line: String) -> (name: String, labels: [String: String], value: Double)? {
        guard let brace = line.firstIndex(of: "{"),
              let endBrace = line.lastIndex(of: "}") else {
            return nil
        }

        let name = String(line[..<brace])
        let labelsText = String(line[line.index(after: brace)..<endBrace])
        let valueText = line[line.index(after: endBrace)...]
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .first
        guard let valueText, let value = Double(valueText) else {
            return nil
        }
        return (name, parseLabels(labelsText), value)
    }

    private static func parseLabels(_ source: String) -> [String: String] {
        var labels: [String: String] = [:]
        var index = source.startIndex

        while index < source.endIndex {
            while index < source.endIndex, source[index] == " " || source[index] == "," {
                index = source.index(after: index)
            }
            guard index < source.endIndex,
                  let equal = source[index...].firstIndex(of: "=") else {
                break
            }
            let key = String(source[index..<equal])
            index = source.index(after: equal)
            guard index < source.endIndex, source[index] == "\"" else {
                break
            }
            index = source.index(after: index)

            var value = ""
            var escaped = false
            while index < source.endIndex {
                let character = source[index]
                index = source.index(after: index)
                if escaped {
                    switch character {
                    case "n": value.append("\n")
                    case "\\": value.append("\\")
                    case "\"": value.append("\"")
                    default: value.append(character)
                    }
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    break
                } else {
                    value.append(character)
                }
            }
            labels[key] = value
        }
        return labels
    }
}
