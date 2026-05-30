import Foundation

enum MonitorState: Int, Codable, Sendable {
    case down = 0
    case up = 1
    case pending = 2
    case maintenance = 3
    case unknown = -1

    var label: String {
        switch self {
        case .down: "Down"
        case .up: "Up"
        case .pending: "Pending"
        case .maintenance: "Maintenance"
        case .unknown: "Unknown"
        }
    }

    var colorName: String {
        switch self {
        case .up: "green"
        case .down: "red"
        case .pending: "orange"
        case .maintenance: "blue"
        case .unknown: "gray"
        }
    }
}

struct MonitorSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let type: String
    let target: String?
    let state: MonitorState
    let responseTimeMilliseconds: Double?
    let sslDaysRemaining: Double?
    let lastCheckTime: Date

    var detailText: String {
        switch state {
        case .down: type.isEmpty ? "Monitor is down" : "\(type) monitor is down"
        case .pending: "Awaiting first result"
        case .maintenance: "Maintenance"
        case .unknown: "Unknown status"
        case .up: target ?? ""
        }
    }
}

enum AuthenticationMode: String, CaseIterable, Identifiable, Sendable {
    case apiKey
    case password

    var id: String { rawValue }

    var label: String {
        switch self {
        case .apiKey: "API Key"
        case .password: "Username & Password"
        }
    }
}

struct KumaCredentials: Sendable {
    let baseURL: URL
    let authenticationMode: AuthenticationMode
    let apiKey: String
    let username: String
    let password: String

    var authorizationValue: String {
        let value: String
        switch authenticationMode {
        case .apiKey:
            value = ":\(apiKey)"
        case .password:
            value = "\(username):\(password)"
        }
        return "Basic \(Data(value.utf8).base64EncodedString())"
    }
}

enum RefreshInterval: Int, CaseIterable, Identifiable, Sendable {
    case thirtySeconds = 30
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .thirtySeconds: "30 seconds"
        case .oneMinute: "60 seconds"
        case .twoMinutes: "120 seconds"
        case .fiveMinutes: "300 seconds"
        }
    }
}

struct PreferencesDraft {
    var baseURL = ""
    var authenticationMode = AuthenticationMode.apiKey
    var apiKey = ""
    var username = ""
    var password = ""
    var refreshInterval = RefreshInterval.thirtySeconds
    var notificationsEnabled = true
    var launchAtLogin = false
}

struct KumaManagementCredentials: Sendable {
    let baseURL: URL
    let username: String
    let password: String
}

struct AddWebsiteDraft: Sendable {
    var name = ""
    var url = "https://"
    var interval = 60
}
