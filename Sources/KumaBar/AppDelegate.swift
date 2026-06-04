import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let terminatesAfterLastWindowClosed = false
    private var model: AppModel?
    private var statusBarController: StatusBarController?
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel()
        let statusBarController = StatusBarController(model: model)
        model.statusBarController = statusBarController
        self.model = model
        self.statusBarController = statusBarController
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                RuntimeLog.write("system wake detected")
                self?.model?.refreshNow(reason: "system wake")
            }
        }
        RuntimeLog.write("application did finish launching")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        RuntimeLog.write("prevented termination after last window closed")
        return Self.terminatesAfterLastWindowClosed
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        RuntimeLog.write("application received termination request")
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        RuntimeLog.write("application will terminate")
    }
}
