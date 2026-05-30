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
}
