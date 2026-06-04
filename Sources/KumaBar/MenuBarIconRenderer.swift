import AppKit

enum MenuBarIconRenderer {
    static func image(status: MenuBarStatus, downCount: Int, appearance: NSAppearance? = nil) -> NSImage {
        let width: CGFloat = status == .down ? 30 : 23
        let size = NSSize(width: width, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let foregroundColor = menuBarForegroundColor(for: appearance)
            drawLogo(color: foregroundColor)
            drawStatus(status: status, downCount: downCount, foregroundColor: foregroundColor)
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = accessibilityDescription(status: status, downCount: downCount)
        return image
    }

    private static func drawLogo(color: NSColor) {
        let path = NSBezierPath()
        path.lineWidth = 1.55
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: NSPoint(x: 1.0, y: 8.7))
        path.line(to: NSPoint(x: 4.7, y: 8.7))
        path.line(to: NSPoint(x: 6.2, y: 4.0))
        path.line(to: NSPoint(x: 8.6, y: 14.2))
        path.line(to: NSPoint(x: 10.6, y: 8.7))
        path.line(to: NSPoint(x: 15.0, y: 8.7))
        color.setStroke()
        path.stroke()
    }

    private static func drawStatus(status: MenuBarStatus, downCount: Int, foregroundColor: NSColor) {
        switch status {
        case .down:
            let value = "\(downCount)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold),
                .foregroundColor: foregroundColor
            ]
            let valueSize = value.size(withAttributes: attributes)
            value.draw(
                at: NSPoint(x: 19 - valueSize.width / 2, y: 8),
                withAttributes: attributes
            )
            drawDot(
                color: .systemRed,
                outlineColor: foregroundColor,
                center: NSPoint(x: 19, y: 4),
                diameter: 5
            )
        case .healthy:
            drawDot(
                color: .systemGreen,
                outlineColor: foregroundColor,
                center: NSPoint(x: 19, y: 9),
                diameter: 7
            )
        case .loading:
            drawDot(
                color: .systemGray,
                outlineColor: foregroundColor,
                center: NSPoint(x: 19, y: 9),
                diameter: 7
            )
        case .unavailable:
            drawDot(
                color: .systemOrange,
                outlineColor: foregroundColor,
                center: NSPoint(x: 19, y: 9),
                diameter: 7
            )
        }
    }

    private static func drawDot(
        color: NSColor,
        outlineColor: NSColor,
        center: NSPoint,
        diameter: CGFloat
    ) {
        let rect = NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()
        outlineColor.withAlphaComponent(0.55).setStroke()
        let outline = NSBezierPath(ovalIn: rect)
        outline.lineWidth = 0.5
        outline.stroke()
    }

    private static func menuBarForegroundColor(for appearance: NSAppearance?) -> NSColor {
        let matches = appearance?.bestMatch(from: [
            .darkAqua,
            .aqua,
            .vibrantDark,
            .vibrantLight,
            .accessibilityHighContrastDarkAqua,
            .accessibilityHighContrastAqua
        ])
        switch matches {
        case .darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua:
            return .white
        default:
            return .black
        }
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
