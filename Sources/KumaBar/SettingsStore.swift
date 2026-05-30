import Foundation
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    enum SettingsError: LocalizedError {
        case invalidURL
        case missingAPIKey
        case missingUsernameOrPassword

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Enter a valid Uptime Kuma URL, including http:// or https://."
            case .missingAPIKey: "Enter an API key."
            case .missingUsernameOrPassword: "Enter both a username and password."
            }
        }
    }

    @Published private(set) var draft = PreferencesDraft()
    @Published private(set) var launchAtLoginMessage: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func load() {
        var loaded = PreferencesDraft()
        loaded.baseURL = defaults.string(forKey: "baseURL") ?? ""
        loaded.authenticationMode = AuthenticationMode(
            rawValue: defaults.string(forKey: "authenticationMode") ?? ""
        ) ?? .apiKey
        loaded.refreshInterval = RefreshInterval(
            rawValue: defaults.integer(forKey: "refreshInterval")
        ) ?? .thirtySeconds
        loaded.notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        loaded.launchAtLogin = SMAppService.mainApp.status == .enabled
        loaded.apiKey = defaults.string(forKey: "apiKey") ?? ""
        loaded.username = defaults.string(forKey: "username") ?? ""
        loaded.password = defaults.string(forKey: "password") ?? ""
        draft = loaded
    }

    func save(_ updated: PreferencesDraft) throws {
        let trimmedURL = updated.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            throw SettingsError.invalidURL
        }
        switch updated.authenticationMode {
        case .apiKey:
            guard !updated.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SettingsError.missingAPIKey
            }
        case .password:
            guard !updated.username.isEmpty, !updated.password.isEmpty else {
                throw SettingsError.missingUsernameOrPassword
            }
        }

        defaults.set(trimmedURL, forKey: "baseURL")
        defaults.set(updated.authenticationMode.rawValue, forKey: "authenticationMode")
        defaults.set(updated.refreshInterval.rawValue, forKey: "refreshInterval")
        defaults.set(updated.notificationsEnabled, forKey: "notificationsEnabled")
        switch updated.authenticationMode {
        case .apiKey:
            defaults.set(updated.apiKey, forKey: "apiKey")
        case .password:
            defaults.set(updated.username, forKey: "username")
            defaults.set(updated.password, forKey: "password")
        }

        var saved = updated
        saved.baseURL = trimmedURL
        saved.launchAtLogin = applyLaunchAtLogin(updated.launchAtLogin)
        draft = saved
    }

    func credentials() throws -> KumaCredentials {
        let trimmedURL = draft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            throw SettingsError.invalidURL
        }
        switch draft.authenticationMode {
        case .apiKey:
            guard !draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SettingsError.missingAPIKey
            }
        case .password:
            guard !draft.username.isEmpty, !draft.password.isEmpty else {
                throw SettingsError.missingUsernameOrPassword
            }
        }
        return KumaCredentials(
            baseURL: url,
            authenticationMode: draft.authenticationMode,
            apiKey: draft.apiKey,
            username: draft.username,
            password: draft.password
        )
    }

    var refreshInterval: RefreshInterval { draft.refreshInterval }
    var notificationsEnabled: Bool { draft.notificationsEnabled }

    func managementCredentials() throws -> KumaManagementCredentials {
        let credentials = try self.credentials()
        return KumaManagementCredentials(
            baseURL: credentials.baseURL,
            username: defaults.string(forKey: "managementUsername") ?? "",
            password: ""
        )
    }

    func managementToken() throws -> String {
        defaults.string(forKey: "managementToken") ?? ""
    }

    func saveManagementUsername(_ username: String) throws {
        defaults.set(username, forKey: "managementUsername")
    }

    func saveManagementToken(_ token: String) throws {
        defaults.set(token, forKey: "managementToken")
    }

    private func applyLaunchAtLogin(_ enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        guard (service.status == .enabled) != enabled else {
            launchAtLoginMessage = nil
            return enabled
        }

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            launchAtLoginMessage = nil
            return service.status == .enabled
        } catch {
            launchAtLoginMessage = "Settings were saved, but Launch at Login could not be changed. Move KumaBar to Applications and try again."
            return service.status == .enabled
        }
    }
}
