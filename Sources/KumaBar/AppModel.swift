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

    let settings: SettingsStore

    private let provider: any MonitorProviding
    private let managementClient = KumaManagementClient()
    private let notifications = NotificationController()
    private let auxiliaryWindows = AuxiliaryWindowController()
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = 0
    weak var statusBarController: StatusBarController?

    init(
        provider: any MonitorProviding = KumaMetricsClient(),
        settings: SettingsStore = SettingsStore()
    ) {
        self.provider = provider
        self.settings = settings
        RuntimeLog.write("app model initialized")
        notifications.requestAuthorizationIfNeeded(enabled: settings.notificationsEnabled)
        restartRefreshLoop(reason: "launch")
    }

    deinit {
        refreshTask?.cancel()
    }

    var menuBarStatus: MenuBarStatus {
        guard !monitors.isEmpty else {
            return errorMessage == nil ? .loading : .unavailable
        }
        guard errorMessage == nil, !isDataStale else {
            return .unavailable
        }
        return downCount > 0 ? .down : .healthy
    }

    var isDataStale: Bool {
        guard let lastRefreshTime else { return false }
        return Self.dataIsStale(
            lastRefreshTime: lastRefreshTime,
            refreshInterval: settings.refreshInterval
        )
    }

    var downCount: Int {
        monitors.filter { $0.state.isProblem }.count
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
        filteredMonitors.filter { $0.state.isProblem }
    }

    var healthyMonitors: [MonitorSnapshot] {
        filteredMonitors.filter { $0.state == .up }
    }

    var otherMonitors: [MonitorSnapshot] {
        filteredMonitors.filter { $0.state != .up && !$0.state.isProblem }
    }

    func savePreferences(_ draft: PreferencesDraft) throws {
        try settings.save(draft)
        notifications.requestAuthorizationIfNeeded(enabled: settings.notificationsEnabled)
        restartRefreshLoop(reason: "settings saved")
    }

    func refreshNow(reason: String = "manual") {
        restartRefreshLoop(reason: reason)
    }

    private func fetchAndApply(reason: String, generation: Int) async {
        guard generation == refreshGeneration, !isRefreshing else { return }
        RuntimeLog.write("refresh started: \(reason)")
        isRefreshing = true
        defer {
            if generation == refreshGeneration {
                isRefreshing = false
            }
        }

        do {
            let credentials = try settings.credentials()
            let latest = try await provider.fetchMonitors(credentials: credentials)
            guard !Task.isCancelled, generation == refreshGeneration else {
                RuntimeLog.write("refresh discarded after cancellation: \(reason)")
                return
            }
            monitors = latest
            lastRefreshTime = Date()
            errorMessage = nil
            notifications.process(latest, enabled: settings.notificationsEnabled)
            statusBarController?.updateIcon()
            RuntimeLog.write(
                "refresh succeeded: monitors=\(latest.count) down=\(latest.filter { $0.state.isProblem }.count)"
            )
        } catch is CancellationError {
            RuntimeLog.write("refresh cancelled: \(reason)")
        } catch {
            guard generation == refreshGeneration else { return }
            errorMessage = error.localizedDescription
            statusBarController?.updateIcon()
            RuntimeLog.write("refresh failed: \(error.localizedDescription)")
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
        RuntimeLog.write("add website completed")
        refreshNow(reason: "website added")
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

    func restartRefreshLoop(reason: String) {
        refreshGeneration += 1
        let generation = refreshGeneration
        refreshTask?.cancel()
        isRefreshing = false
        RuntimeLog.write("refresh loop restarted: \(reason)")
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.fetchAndApply(reason: reason, generation: generation)
            while !Task.isCancelled {
                let duration = UInt64(self.settings.refreshInterval.rawValue) * 1_000_000_000
                try? await Task.sleep(nanoseconds: duration)
                guard !Task.isCancelled else { return }
                await self.fetchAndApply(reason: "scheduled", generation: generation)
            }
        }
    }

    nonisolated static func dataIsStale(
        lastRefreshTime: Date,
        refreshInterval: RefreshInterval,
        now: Date = Date()
    ) -> Bool {
        let staleAfter = max(TimeInterval(refreshInterval.rawValue * 3), 90)
        return now.timeIntervalSince(lastRefreshTime) > staleAfter
    }
}

enum MenuBarStatus: Equatable {
    case loading
    case healthy
    case down
    case unavailable
}
