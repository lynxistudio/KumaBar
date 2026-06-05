import AppKit
import Foundation
import Testing
@testable import KumaBar

@Suite
struct MetricsParserTests {
    @Test
    func testParsesMonitorMetricsAndEscapedLabels() {
        let date = Date(timeIntervalSince1970: 123)
        let metrics = """
        # HELP monitor_status Monitor Status
        monitor_status{monitor_name="Home \\"Page\\"",monitor_type="http",monitor_url="https://example.com",monitor_id="42"} 1
        monitor_response_time{monitor_name="Home \\"Page\\"",monitor_type="http",monitor_url="https://example.com",monitor_id="42"} 18
        monitor_cert_days_remaining{monitor_name="Home \\"Page\\"",monitor_type="http",monitor_url="https://example.com",monitor_id="42"} 52
        """

        let monitors = MetricsParser.parse(metrics, fetchedAt: date)

        #expect(monitors.count == 1)
        #expect(monitors[0].id == "42")
        #expect(monitors[0].name == "Home \"Page\"")
        #expect(monitors[0].state == .up)
        #expect(monitors[0].responseTimeMilliseconds == 18)
        #expect(monitors[0].sslDaysRemaining == 52)
        #expect(monitors[0].lastCheckTime == date)
    }

    @Test
    func testSortsMonitorsByName() {
        let metrics = """
        monitor_status{monitor_name="Zulu",monitor_type="ping",monitor_id="2"} 0
        monitor_status{monitor_name="Alpha",monitor_type="http",monitor_id="1"} 1
        """

        let monitors = MetricsParser.parse(metrics, fetchedAt: Date())

        #expect(monitors.map(\.name) == ["Alpha", "Zulu"])
        #expect(monitors.map(\.state) == [.up, .down])
    }

    @Test
    func testProblemStatesAreClassifiedConsistently() {
        #expect(MonitorState.down.isProblem)
        #expect(MonitorState.unknown.isProblem)
        #expect(MonitorState.up.isProblem == false)
        #expect(MonitorState.pending.isProblem == false)
        #expect(MonitorState.maintenance.isProblem == false)
        #expect(MonitorState.unknown.colorName == "red")
    }

    @Test
    func testUnexpectedMetricStatusIsTreatedAsProblem() {
        let metrics = """
        monitor_status{monitor_name="Mystery",monitor_type="http",monitor_id="9"} 9
        """

        let monitors = MetricsParser.parse(metrics, fetchedAt: Date())

        #expect(monitors.count == 1)
        #expect(monitors[0].state == .unknown)
        #expect(monitors[0].state.isProblem)
    }

    @Test
    func testMetricsEndpointDoesNotGainTextExtension() throws {
        let baseURL = try #require(URL(string: "http://127.0.0.1:3001"))

        let metricsURL = KumaMetricsClient.metricsURL(for: baseURL)

        #expect(metricsURL.absoluteString == "http://127.0.0.1:3001/metrics")
    }

    @Test
    func testManagementSocketURLUsesWebSocketTransport() throws {
        let baseURL = try #require(URL(string: "http://127.0.0.1:3001"))

        let socketURL = try #require(KumaManagementClient.socketURL(for: baseURL))

        #expect(socketURL.scheme == "ws")
        #expect(socketURL.absoluteString == "ws://127.0.0.1:3001/socket.io/?EIO=4&transport=websocket")
    }

    @Test
    func testAddWebsitePayloadUsesOnlyCrossVersionFields() {
        let payload = KumaManagementClient.monitorPayload(
            name: "Example",
            url: "https://example.com",
            interval: 60
        )

        #expect(payload.keys.sorted() == [
            "accepted_statuscodes",
            "interval",
            "maxredirects",
            "maxretries",
            "method",
            "name",
            "notificationIDList",
            "retryInterval",
            "type",
            "upsideDown",
            "url"
        ])
        #expect(payload["conditions"] == nil)
    }

    @Test
    func testMenuBarIconsContainVisibleStatusColors() throws {
        let healthy = try #require(bitmap(for: MenuBarIconRenderer.image(status: .healthy, downCount: 0)))
        let down = try #require(bitmap(for: MenuBarIconRenderer.image(status: .down, downCount: 2)))

        #expect(containsColor(in: healthy) { $0.greenComponent > 0.55 && $0.redComponent < 0.45 })
        #expect(containsColor(in: down) { $0.redComponent > 0.55 && $0.greenComponent < 0.45 })
        #expect(down.pixelsWide > healthy.pixelsWide)
    }

    @Test
    func testMenuBarLogoFollowsLightAndDarkAppearances() throws {
        let lightAppearance = try #require(NSAppearance(named: .aqua))
        let darkAppearance = try #require(NSAppearance(named: .darkAqua))
        let lightBitmap = try #require(bitmap(
            for: MenuBarIconRenderer.image(
                status: .healthy,
                downCount: 0,
                appearance: lightAppearance
            )
        ))
        let darkBitmap = try #require(bitmap(
            for: MenuBarIconRenderer.image(
                status: .healthy,
                downCount: 0,
                appearance: darkAppearance
            )
        ))

        let lightLogoLuminance = try #require(averageLuminance(in: lightBitmap, xRange: 0..<16))
        let darkLogoLuminance = try #require(averageLuminance(in: darkBitmap, xRange: 0..<16))

        #expect(lightLogoLuminance < 0.35)
        #expect(darkLogoLuminance > 0.65)
    }

    @Test
    @MainActor
    func testClosingLastWindowDoesNotTerminateMenuBarApp() {
        #expect(AppDelegate.terminatesAfterLastWindowClosed == false)
    }

    @Test
    @MainActor
    func testSettingsLoadsCredentialsFromLocalPreferences() throws {
        let suiteName = "KumaBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("http://127.0.0.1:3001", forKey: "baseURL")
        defaults.set(AuthenticationMode.apiKey.rawValue, forKey: "authenticationMode")
        defaults.set("local-api-key", forKey: "apiKey")
        defaults.set("local-token", forKey: "managementToken")

        let settings = SettingsStore(defaults: defaults)

        #expect(settings.draft.apiKey == "local-api-key")
        #expect(try settings.managementToken() == "local-token")
    }

    @Test
    @MainActor
    func testManagementURLCanBeSavedAndClearedPerMonitor() throws {
        let suiteName = "KumaBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        let monitor = MonitorSnapshot(
            id: "monitor-1",
            name: "Example",
            type: "http",
            target: "https://example.com",
            state: .up,
            responseTimeMilliseconds: 42,
            sslDaysRemaining: nil,
            lastCheckTime: Date()
        )

        try settings.saveManagementURL(" https://admin.example.com ", for: monitor)

        #expect(settings.managementURL(for: monitor) == "https://admin.example.com")

        try settings.saveManagementURL("", for: monitor)

        #expect(settings.managementURL(for: monitor) == nil)
    }

    @Test
    func testMonitorDataBecomesStaleAfterThreeRefreshIntervals() {
        let now = Date(timeIntervalSince1970: 1_000)

        #expect(AppModel.dataIsStale(
            lastRefreshTime: now.addingTimeInterval(-89),
            refreshInterval: .thirtySeconds,
            now: now
        ) == false)
        #expect(AppModel.dataIsStale(
            lastRefreshTime: now.addingTimeInterval(-91),
            refreshInterval: .thirtySeconds,
            now: now
        ) == true)
        #expect(AppModel.dataIsStale(
            lastRefreshTime: now.addingTimeInterval(-899),
            refreshInterval: .fiveMinutes,
            now: now
        ) == false)
        #expect(AppModel.dataIsStale(
            lastRefreshTime: now.addingTimeInterval(-901),
            refreshInterval: .fiveMinutes,
            now: now
        ) == true)
    }

    @Test
    @MainActor
    func testManualRefreshRestartsTheFetchLoop() async throws {
        let suiteName = "KumaBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("http://127.0.0.1:3001", forKey: "baseURL")
        defaults.set(AuthenticationMode.apiKey.rawValue, forKey: "authenticationMode")
        defaults.set("local-api-key", forKey: "apiKey")
        defaults.set(RefreshInterval.fiveMinutes.rawValue, forKey: "refreshInterval")
        defaults.set(false, forKey: "notificationsEnabled")

        let counter = FetchCounter()
        let model = AppModel(
            provider: CountingMonitorProvider(counter: counter),
            settings: SettingsStore(defaults: defaults)
        )
        try await waitForFetchCount(1, counter: counter)
        let initialCount = await counter.value

        model.refreshNow(reason: "test")

        try await waitForFetchCount(initialCount + 1, counter: counter)
        #expect(await counter.value > initialCount)
    }

    private func waitForFetchCount(_ expected: Int, counter: FetchCounter) async throws {
        for _ in 0..<20 {
            if await counter.value >= expected { return }
            try await Task.sleep(for: .milliseconds(25))
        }
        Issue.record("Timed out waiting for fetch count \(expected)")
    }

    private func bitmap(for image: NSImage) -> NSBitmapImageRep? {
        guard let data = image.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: data)
    }

    private func containsColor(
        in bitmap: NSBitmapImageRep,
        matching predicate: (NSColor) -> Bool
    ) -> Bool {
        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                if color.alphaComponent > 0.3, predicate(color) {
                    return true
                }
            }
        }
        return false
    }

    private func averageLuminance(in bitmap: NSBitmapImageRep, xRange: Range<Int>) -> Double? {
        var total = 0.0
        var count = 0
        for x in xRange where x < bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.3 else {
                    continue
                }
                total += color.redComponent * 0.2126
                    + color.greenComponent * 0.7152
                    + color.blueComponent * 0.0722
                count += 1
            }
        }
        return count > 0 ? total / Double(count) : nil
    }
}

private actor FetchCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private struct CountingMonitorProvider: MonitorProviding {
    let counter: FetchCounter

    func fetchMonitors(credentials: KumaCredentials) async throws -> [MonitorSnapshot] {
        await counter.increment()
        return [
            MonitorSnapshot(
                id: "test",
                name: "Test Monitor",
                type: "http",
                target: "https://example.com",
                state: .up,
                responseTimeMilliseconds: 12,
                sslDaysRemaining: nil,
                lastCheckTime: Date()
            )
        ]
    }
}
