import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var lastIconKey: IconKey?

    init(model: AppModel) {
        self.model = model
        super.init()

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 500)
        popover.contentViewController = NSHostingController(
            rootView: MenuContentView().environmentObject(model)
        )

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.imagePosition = .imageOnly
        }

        updateIcon(force: true)
        RuntimeLog.write("native status item initialized")
    }

    func closeMenu() {
        popover.performClose(nil)
    }

    func updateIcon(force: Bool = false) {
        guard let button = statusItem.button else { return }
        let iconKey = IconKey(
            status: model.menuBarStatus,
            downCount: model.downCount,
            appearanceName: button.effectiveAppearance.bestMatch(from: [
                .darkAqua,
                .aqua,
                .vibrantDark,
                .vibrantLight,
                .accessibilityHighContrastDarkAqua,
                .accessibilityHighContrastAqua
            ])
        )
        guard force || iconKey != lastIconKey else { return }
        lastIconKey = iconKey
        let image = MenuBarIconRenderer.image(
            status: iconKey.status,
            downCount: iconKey.downCount,
            appearance: button.effectiveAppearance
        )
        button.image = image
        button.toolTip = image.accessibilityDescription
    }

    @objc
    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closeMenu()
        } else {
            if model.isDataStale {
                model.refreshNow(reason: "menu opened with stale data")
            }
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
        }
    }
}

private struct IconKey: Equatable {
    let status: MenuBarStatus
    let downCount: Int
    let appearanceName: NSAppearance.Name?
}
