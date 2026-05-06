#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

private struct IconSize {
    let filename: String
    let pixels: Int
}

private let iconSizes: [IconSize] = [
    IconSize(filename: "icon_16x16.png", pixels: 16),
    IconSize(filename: "icon_16x16@2x.png", pixels: 32),
    IconSize(filename: "icon_32x32.png", pixels: 32),
    IconSize(filename: "icon_32x32@2x.png", pixels: 64),
    IconSize(filename: "icon_128x128.png", pixels: 128),
    IconSize(filename: "icon_128x128@2x.png", pixels: 256),
    IconSize(filename: "icon_256x256.png", pixels: 256),
    IconSize(filename: "icon_256x256@2x.png", pixels: 512),
    IconSize(filename: "icon_512x512.png", pixels: 512),
    IconSize(filename: "icon_512x512@2x.png", pixels: 1024),
]

private let boltPathPoints: [(x: CGFloat, y: CGFloat)] = [
    (0.64, 0.06),
    (0.18, 0.58),
    (0.42, 0.58),
    (0.30, 0.94),
    (0.84, 0.40),
    (0.60, 0.40),
    (0.70, 0.06),
]

private func renderIcon(pixels: Int) -> Data {
    let s = CGFloat(pixels)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    context.translateBy(x: 0, y: s)
    context.scaleBy(x: 1, y: -1)

    let cornerRadius = s * 0.24
    let strokeWidth = max(1.5, s * 0.14)
    let boltInset = s * 0.19
    let boltCornerStroke = max(0.5, s * 0.04)

    let tileRect = CGRect(x: 0, y: 0, width: s, height: s)
    let tilePath = CGPath(
        roundedRect: tileRect,
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    context.addPath(tilePath)
    context.fillPath()

    let boltRect = CGRect(
        x: boltInset,
        y: boltInset,
        width: s - 2 * boltInset,
        height: s - 2 * boltInset
    )
    let bolt = CGMutablePath()
    let first = boltPathPoints[0]
    bolt.move(to: CGPoint(
        x: boltRect.minX + first.x * boltRect.width,
        y: boltRect.minY + first.y * boltRect.height
    ))
    for i in 1 ..< boltPathPoints.count {
        let p = boltPathPoints[i]
        bolt.addLine(to: CGPoint(
            x: boltRect.minX + p.x * boltRect.width,
            y: boltRect.minY + p.y * boltRect.height
        ))
    }
    bolt.closeSubpath()

    context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
    context.addPath(bolt)
    context.fillPath()

    context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1)
    context.setLineWidth(boltCornerStroke)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.addPath(bolt)
    context.strokePath()

    context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1)
    context.setLineWidth(strokeWidth)
    context.setLineCap(.butt)
    context.setLineJoin(.miter)
    context.addPath(tilePath)
    context.strokePath()

    let cgImage = context.makeImage()!
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    return bitmap.representation(using: .png, properties: [:])!
}

private func writeIcon(size: IconSize, into directory: URL) throws {
    let data = renderIcon(pixels: size.pixels)
    let url = directory.appendingPathComponent(size.filename)
    try data.write(to: url)
    print("wrote \(size.filename) (\(size.pixels) px, \(data.count) bytes)")
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let assetDir = repoRoot
    .appendingPathComponent("SpotlightCaffeinate")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")

guard FileManager.default.fileExists(atPath: assetDir.path) else {
    fputs("error: missing AppIcon.appiconset at \(assetDir.path)\n", stderr)
    exit(1)
}

for size in iconSizes {
    try writeIcon(size: size, into: assetDir)
}

print("done — \(iconSizes.count) PNGs written to \(assetDir.path)")
