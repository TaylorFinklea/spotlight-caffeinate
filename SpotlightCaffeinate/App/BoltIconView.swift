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

private enum CaffeinateIconRenderer {
    static func image(isRunning: Bool, size: CGFloat) -> NSImage {
        let imageSize = NSSize(width: size, height: size)
        let image = NSImage(size: imageSize)
        let bounds = CGRect(origin: .zero, size: imageSize)
        let cornerRadius = size * 0.24
        let inset = size * 0.19
        let strokeWidth = max(1, size * 0.10)

        image.lockFocus()

        let tilePath = NSBezierPath(
            roundedRect: bounds.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2),
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )
        let boltBounds = bounds.insetBy(dx: inset, dy: inset)
        let boltPath = NSBezierPath(cgPath: boltPath(in: boltBounds))

        if isRunning {
            NSColor.labelColor.setFill()
            tilePath.fill()

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            boltPath.fill()
            NSGraphicsContext.restoreGraphicsState()
        } else {
            NSColor.labelColor.setStroke()
            tilePath.lineWidth = strokeWidth
            tilePath.stroke()

            NSColor.labelColor.setFill()
            boltPath.fill()
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func boltPath(in rect: CGRect) -> CGPath {
        let mutablePath = CGMutablePath()
        mutablePath.move(to: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.04))
        mutablePath.addLine(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.54))
        mutablePath.addLine(to: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.54))
        mutablePath.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.96))
        mutablePath.addLine(to: CGPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.40))
        mutablePath.addLine(to: CGPoint(x: rect.minX + rect.width * 0.56, y: rect.minY + rect.height * 0.40))
        mutablePath.addLine(to: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + rect.height * 0.04))
        mutablePath.closeSubpath()
        return mutablePath
    }
}

struct BoltIconView: View {
    let isRunning: Bool
    let size: CGFloat

    private var cornerRadius: CGFloat { size * 0.24 }
    private var strokeWidth: CGFloat { max(1, size * 0.10) }
    private var boltInset: CGFloat { size * 0.19 }

    var body: some View {
        ZStack {
            if isRunning {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.primary)

                BoltShape()
                    .padding(boltInset)
                    .blendMode(.destinationOut)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.primary, lineWidth: strokeWidth)

                BoltShape()
                    .padding(boltInset)
                    .foregroundStyle(.primary)
            }
        }
        .compositingGroup()
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct MenuBarBoltIconView: View {
    let isRunning: Bool

    var body: some View {
        Image(nsImage: CaffeinateIconRenderer.image(isRunning: isRunning, size: 13))
            .interpolation(.high)
            .accessibilityHidden(true)
    }
}
