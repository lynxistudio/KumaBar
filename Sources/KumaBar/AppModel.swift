import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var monitors: [MonitorSnapshot] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshTime: Date?
    @Published private(set) var isAddingWebsite = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    let settings = SettingsStore()

    private let provider: any MonitorProviding
    private let managementClient = KumaManagementClient()
    private let notifications = NotificationController()
    private let auxiliaryWindows = AuxiliaryWindowController()
    private var refreshTask: Task<Void, Never>?
    weak var statusBarController: StatusBarController?

    init(provider: any MonitorProviding = KumaMetricsClient()) {
        self.provider = provider
        RuntimeLog.write("app model initialized")
        notifications.requestAuthorizationIfNeeded(enabled: settings.notificationsEnabled)
        restartRefreshLoop()
    }

    deinit {
        refreshTask?.cancel()
    }

    var menuBarStatus: MenuBarStatus {
        guard !monitors.isEmpty else {
            return errorMessage == nil ? .loading : .unavailable
        }
        return downCount > 0 ? .down : .healthy
    }

    var downCount: Int {
        monitors.filter { $0.state == .down }.count
    }

    var filteredMonitors: [MonitorSnapshot] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return monitors }
        return monitors.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.type.localizedCaseInsensitiveContains(query)
                || ($0.target?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var failedMonitors: [MonitorSnapshot] {
        filteredMonitors.filter { $0.state == .down }
    }

    var healthyMonitors: [MonitorSnapshot] {
        filteredMonitors.filter { $0.state == .up }
    }

    var otherMonitors: [MonitorSnapshot] {
        filteredMonitors.filter { $0.state != .up && $0.state != .down }
    }

    func savePreferences(_ draft: PreferencesDraft) throws {
        try settings.save(draft)
        notifications.requestAuthorizationIfNeeded(enabled: settings.notificationsEnabled)
        restartRefreshLoop()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        do {
            let credentials = try settings.credentials()
            isRefreshing = true
            defer { isRefreshing = false }
            let latest = try await provider.fetchMonitors(credentials: credentials)
            monitors = latest
            lastRefreshTime = Date()
            errorMessage = nil
            notifications.process(latest, enabled: settings.notificationsEnabled)
        } catch {
            isRefreshing = false
            errorMessage = error.localizedDescription
        }
    }

    func openDashboard() {
        guard let credentials = try? settings.credentials() else {
            errorMessage = "Configure your Uptime Kuma URL first."
            return
        }
        NSWorkspace.shared.open(credentials.baseURL)
    }

    func openPreferences() {
        statusBarController?.closeMenu()
        auxiliaryWindows.showPreferences(model: self)
    }

    func openAddWebsite() {
        statusBarController?.closeMenu()
        auxiliaryWindows.showAddWebsite(model: self)
    }

    func makeAddWebsiteDraft() -> AddWebsiteDraft {
        AddWebsiteDraft()
    }

    func addWebsite(_ draft: AddWebsiteDraft) async throws {
        RuntimeLog.write("add website started")
        isAddingWebsite = true
        defer { isAddingWebsite = false }
        let credentials = try settings.managementCredentials()
        let token = try settings.managementToken()
        guard !token.isEmpty else {
            throw KumaManagementClient.ClientError.missingManagementLogin
        }
        try await managementClient.addWebsite(
            baseURL: credentials.baseURL,
            managementToken: token,
            draft: draft
        )
        RuntimeLog.write("add website completed; waiting for scheduled refresh")
    }

    func saveManagementLogin(username: String, password: String) async throws {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty, !password.isEmpty else {
            throw KumaManagementClient.ClientError.missingManagementCredentials
        }
        let baseURL = try settings.credentials().baseURL
        let credentials = KumaManagementCredentials(
            baseURL: baseURL,
            username: trimmedUsername,
            password: password
        )
        let token = try await managementClient.login(credentials: credentials)
        try settings.saveManagementUsername(trimmedUsername)
        try settings.saveManagementToken(token)
    }

    func restartRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            while !Task.isCancelled {
                let duration = UInt64(self.settings.refreshInterval.rawValue) * 1_000_000_000
                try? await Task.sleep(nanoseconds: duration)
                guard !Task.isCancelled else { return }
                await self.refresh()
            }
        }
    }
}

enum MenuBarStatus {
    case loading
    case healthy
    case down
    case unavailable
}
