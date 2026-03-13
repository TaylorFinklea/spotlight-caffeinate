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

private struct MenuBarTemplateBoltIconView: View {
    let isRunning: Bool
    let size: CGFloat

    private var cornerRadius: CGFloat { size * 0.24 }
    private var strokeWidth: CGFloat { max(1, size * 0.10) }
    private var boltInset: CGFloat { size * 0.19 }

    var body: some View {
        ZStack {
            if isRunning {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.black)

                BoltShape()
                    .padding(boltInset)
                    .blendMode(.destinationOut)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.black, lineWidth: strokeWidth)

                BoltShape()
                    .padding(boltInset)
                    .foregroundStyle(.black)
            }
        }
        .compositingGroup()
        .frame(width: size, height: size)
    }
}

@MainActor
private enum MenuBarBoltRenderer {
    private static var cache: [Bool: NSImage] = [:]

    static func image(isRunning: Bool, size: CGFloat) -> NSImage {
        if let cached = cache[isRunning] {
            return cached
        }

        let renderer = ImageRenderer(
            content: MenuBarTemplateBoltIconView(isRunning: isRunning, size: size)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        let image = renderer.nsImage ?? NSImage(size: NSSize(width: size, height: size))
        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        cache[isRunning] = image
        return image
    }
}

struct BoltIconView: View {
    let isRunning: Bool
    let size: CGFloat

    private var cornerRadius: CGFloat { size * 0.24 }
    private var strokeWidth: CGFloat { max(1, size * 0.08) }
    private var boltInset: CGFloat { size * 0.19 }

    var body: some View {
        ZStack {
            if isRunning {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.black)

                BoltShape()
                    .padding(boltInset)
                    .foregroundStyle(.white)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(.black, lineWidth: strokeWidth)
                    }

                BoltShape()
                    .padding(boltInset)
                    .foregroundStyle(.black)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct MenuBarBoltIconView: View {
    let isRunning: Bool

    var body: some View {
        Image(nsImage: MenuBarBoltRenderer.image(isRunning: isRunning, size: 15))
            .interpolation(.high)
            .accessibilityHidden(true)
    }
}
