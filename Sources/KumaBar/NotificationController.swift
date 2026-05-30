import Foundation
import UserNotifications

@MainActor
final class NotificationController {
    private var previousStates: [String: MonitorState] = [:]
    private var isSeeded = false

    func requestAuthorizationIfNeeded(enabled: Bool) {
        guard enabled else { return }
        Task {
            guard await Self.needsAuthorizationRequest() else { return }
            await Self.requestAuthorization()
        }
    }

    private nonisolated static func needsAuthorizationRequest() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus == .notDetermined)
            }
        }
    }

    private nonisolated static func requestAuthorization() async {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                continuation.resume()
            }
        }
    }

    func process(_ monitors: [MonitorSnapshot], enabled: Bool) {
        defer {
            previousStates = Dictionary(uniqueKeysWithValues: monitors.map { ($0.id, $0.state) })
            isSeeded = true
        }
        guard enabled, isSeeded else { return }

        for monitor in monitors {
            guard let previous = previousStates[monitor.id], previous != monitor.state else {
                continue
            }
            if previous == .up, monitor.state == .down {
                send(title: "\(monitor.name) is down", body: monitor.detailText)
            } else if previous == .down, monitor.state == .up {
                send(title: "\(monitor.name) recovered", body: "Monitor is responding normally.")
            }
        }
    }

    private func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
