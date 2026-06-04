import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []

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

        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateIcon()
                }
            }
            .store(in: &cancellables)

        updateIcon()
        RuntimeLog.write("native status item initialized")
    }

    func closeMenu() {
        popover.performClose(nil)
    }

    func updateIcon() {
        guard let button = statusItem.button else { return }
        let image = MenuBarIconRenderer.image(
            status: model.menuBarStatus,
            downCount: model.downCount,
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
