import AppKit

enum MenuBarIconRenderer {
    static func image(status: MenuBarStatus, downCount: Int) -> NSImage {
        let width: CGFloat = status == .down ? 30 : 23
        let size = NSSize(width: width, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            drawLogo()
            drawStatus(status: status, downCount: downCount)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = accessibilityDescription(status: status, downCount: downCount)
        return image
    }

    private static func drawLogo() {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let logo = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        logo?.draw(
            in: NSRect(x: 0, y: 2, width: 15, height: 14),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
    }

    private static func drawStatus(status: MenuBarStatus, downCount: Int) {
        switch status {
        case .down:
            let value = "\(downCount)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold),
                .foregroundColor: NSColor.labelColor
            ]
            let valueSize = value.size(withAttributes: attributes)
            value.draw(
                at: NSPoint(x: 19 - valueSize.width / 2, y: 8),
                withAttributes: attributes
            )
            drawDot(color: .systemRed, center: NSPoint(x: 19, y: 4), diameter: 5)
        case .healthy:
            drawDot(color: .systemGreen, center: NSPoint(x: 19, y: 9), diameter: 7)
        case .loading:
            drawDot(color: .systemGray, center: NSPoint(x: 19, y: 9), diameter: 7)
        case .unavailable:
            drawDot(color: .systemOrange, center: NSPoint(x: 19, y: 9), diameter: 7)
        }
    }

    private static func drawDot(color: NSColor, center: NSPoint, diameter: CGFloat) {
        let rect = NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()
        NSColor.labelColor.withAlphaComponent(0.55).setStroke()
        let outline = NSBezierPath(ovalIn: rect)
        outline.lineWidth = 0.5
        outline.stroke()
    }

    private static func accessibilityDescription(status: MenuBarStatus, downCount: Int) -> String {
        switch status {
        case .loading: "KumaBar loading"
        case .healthy: "KumaBar monitors healthy"
        case .down: "KumaBar \(downCount) monitors down"
        case .unavailable: "KumaBar unavailable"
        }
    }
}
