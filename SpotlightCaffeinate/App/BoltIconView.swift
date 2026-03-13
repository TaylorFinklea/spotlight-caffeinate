import AppKit
import SwiftUI

private struct BoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.04))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.54))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.54))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.96))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.40))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.56, y: rect.minY + rect.height * 0.40))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + rect.height * 0.04))
            path.closeSubpath()
        }
    }
}

struct BoltIconView: View {
    var size: CGFloat

    var body: some View {
        BoltShape()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private enum MenuBarBoltAsset {
    static let image: NSImage = {
        let size = NSSize(width: 11, height: 11)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.labelColor.setFill()

        let path = NSBezierPath()
        path.move(to: CGPoint(x: size.width * 0.58, y: size.height * 0.96))
        path.line(to: CGPoint(x: size.width * 0.26, y: size.height * 0.46))
        path.line(to: CGPoint(x: size.width * 0.48, y: size.height * 0.46))
        path.line(to: CGPoint(x: size.width * 0.38, y: size.height * 0.04))
        path.line(to: CGPoint(x: size.width * 0.76, y: size.height * 0.60))
        path.line(to: CGPoint(x: size.width * 0.56, y: size.height * 0.60))
        path.line(to: CGPoint(x: size.width * 0.66, y: size.height * 0.96))
        path.close()
        path.fill()

        image.unlockFocus()
        image.isTemplate = true

        return image
    }()
}

struct MenuBarBoltIconView: View {
    var body: some View {
        Image(nsImage: MenuBarBoltAsset.image)
            .interpolation(.high)
            .accessibilityHidden(true)
    }
}
