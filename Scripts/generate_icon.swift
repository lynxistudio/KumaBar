#!/usr/bin/env swift
import AppKit

let outputDirectory = CommandLine.arguments.dropFirst().first ?? "Assets/AppIcon.iconset"
let outputICNS = CommandLine.arguments.dropFirst(2).first ?? "Assets/AppIcon.icns"
let fileManager = FileManager.default
try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(name: String, size: Int) throws {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "KumaBarIcon", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = CGFloat(size) * 0.055
    let background = canvas.insetBy(dx: inset, dy: inset)
    let radius = CGFloat(size) * 0.22
    let backgroundPath = NSBezierPath(roundedRect: background, xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.075, green: 0.10, blue: 0.14, alpha: 1).setFill()
    backgroundPath.fill()

    let barWidth = CGFloat(size) * 0.092
    let gap = CGFloat(size) * 0.070
    let centerX = CGFloat(size) * 0.42
    let barBottom = CGFloat(size) * 0.25
    let heights = [0.25, 0.40, 0.57].map { CGFloat(size) * $0 }
    for index in 0..<3 {
        let rect = NSRect(
            x: centerX - CGFloat(index - 1) * (barWidth + gap) - barWidth / 2,
            y: barBottom,
            width: barWidth,
            height: heights[index]
        )
        let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
        NSColor(calibratedRed: 0.31, green: 0.84, blue: 0.56, alpha: 1).setFill()
        path.fill()
    }

    let dotSize = CGFloat(size) * 0.20
    let dotRect = NSRect(
        x: CGFloat(size) * 0.63,
        y: CGFloat(size) * 0.60,
        width: dotSize,
        height: dotSize
    )
    NSColor(calibratedRed: 0.31, green: 0.84, blue: 0.56, alpha: 1).setFill()
    NSBezierPath(ovalIn: dotRect).fill()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "KumaBarIcon", code: 2)
    }
    try data.write(to: URL(fileURLWithPath: outputDirectory).appendingPathComponent(name))
}

for (name, size) in sizes {
    try drawIcon(name: name, size: size)
}

func bigEndianData(_ value: UInt32) -> Data {
    var bigEndian = value.bigEndian
    return withUnsafeBytes(of: &bigEndian) { Data($0) }
}

let layers = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var chunks = Data()
for (type, fileName) in layers {
    let png = try Data(contentsOf: URL(fileURLWithPath: outputDirectory).appendingPathComponent(fileName))
    chunks.append(Data(type.utf8))
    chunks.append(bigEndianData(UInt32(png.count + 8)))
    chunks.append(png)
}

var icns = Data("icns".utf8)
icns.append(bigEndianData(UInt32(chunks.count + 8)))
icns.append(chunks)
try icns.write(to: URL(fileURLWithPath: outputICNS))
