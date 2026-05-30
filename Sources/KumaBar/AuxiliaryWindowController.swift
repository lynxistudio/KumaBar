import AppKit
import SwiftUI

@MainActor
final class AuxiliaryWindowController {
    private var preferencesWindow: NSWindow?
    private var addWebsiteWindow: NSWindow?

    func showPreferences(model: AppModel) {
        if let preferencesWindow {
            present(preferencesWindow)
            return
        }

        let window = makeWindow(
            title: "KumaBar Settings",
            size: NSSize(width: 470, height: 560),
            rootView: PreferencesView().environmentObject(model)
        )
        preferencesWindow = window
        present(window)
    }

    func showAddWebsite(model: AppModel) {
        if let addWebsiteWindow {
            present(addWebsiteWindow)
            return
        }

        let window = makeWindow(
            title: "Add Website",
            size: NSSize(width: 470, height: 340),
            rootView: AddWebsiteView(
                draft: model.makeAddWebsiteDraft(),
                onClose: { [weak self] in
                    self?.closeAddWebsite()
                }
            )
            .environmentObject(model)
        )
        addWebsiteWindow = window
        present(window)
    }

    private func closeAddWebsite() {
        let window = addWebsiteWindow
        addWebsiteWindow = nil
        DispatchQueue.main.async {
            window?.close()
        }
    }

    private func makeWindow<Content: View>(
        title: String,
        size: NSSize,
        rootView: Content
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentViewController = NSHostingController(rootView: rootView)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func present(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
