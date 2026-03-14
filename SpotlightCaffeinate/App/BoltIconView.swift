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

private struct BoltIconMetrics {
    let size: CGFloat

    var cornerRadius: CGFloat { size * 0.24 }
    var strokeWidth: CGFloat { max(1, size * 0.08) }
    var innerInset: CGFloat { strokeWidth + max(0.5, size * 0.03) }
    var boltInset: CGFloat { size * 0.19 }
}

private struct BoltFillMaskView: View {
    let metrics: BoltIconMetrics
    let fillFraction: CGFloat

    var body: some View {
        let innerSize = max(0, metrics.size - (metrics.innerInset * 2))

        Rectangle()
            .frame(width: innerSize, height: innerSize * fillFraction)
            .frame(width: innerSize, height: innerSize, alignment: .bottom)
            .padding(metrics.innerInset)
    }
}

private enum BoltIconStyle {
    case app
    case menuBarTemplate
}

private struct ProgressBoltIconView: View {
    let fillFraction: CGFloat
    let size: CGFloat
    let style: BoltIconStyle

    private var clampedFillFraction: CGFloat {
        min(max(fillFraction, 0), 1)
    }

    private var metrics: BoltIconMetrics {
        BoltIconMetrics(size: size)
    }

    private var tileShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
    }

    private var clippedFillMask: some View {
        BoltFillMaskView(metrics: metrics, fillFraction: clampedFillFraction)
            .clipShape(tileShape.inset(by: metrics.innerInset))
    }

    var body: some View {
        ZStack {
            switch style {
            case .app:
                appIcon
            case .menuBarTemplate:
                menuBarTemplateIcon
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var appIcon: some View {
        ZStack {
            tileShape
                .fill(.white)

            if clampedFillFraction > 0 {
                clippedFillMask
                    .foregroundStyle(.black)
            }

            BoltShape()
                .padding(metrics.boltInset)
                .foregroundStyle(.black)

            if clampedFillFraction > 0 {
                BoltShape()
                    .padding(metrics.boltInset)
                    .foregroundStyle(.white)
                    .mask(clippedFillMask)
            }

            tileShape
                .stroke(.black, lineWidth: metrics.strokeWidth)
        }
    }

    private var menuBarTemplateIcon: some View {
        ZStack {
            if clampedFillFraction > 0 {
                clippedFillMask
                    .foregroundStyle(.black)
            }

            BoltShape()
                .padding(metrics.boltInset)
                .foregroundStyle(.black)

            if clampedFillFraction > 0 {
                BoltShape()
                    .padding(metrics.boltInset)
                    .foregroundStyle(.black)
                    .mask(clippedFillMask)
                    .blendMode(.destinationOut)
            }

            tileShape
                .stroke(.black, lineWidth: metrics.strokeWidth)
        }
        .compositingGroup()
    }
}

private struct MenuBarBoltCacheKey: Hashable {
    let pixelRows: Int
    let step: Int
}

@MainActor
private enum MenuBarBoltRenderer {
    private static var cache: [MenuBarBoltCacheKey: NSImage] = [:]

    static func image(fillFraction: CGFloat, size: CGFloat) -> NSImage {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let pixelRows = max(1, Int(round(size * scale)))
        let step = max(0, min(pixelRows, Int((min(max(fillFraction, 0), 1) * CGFloat(pixelRows)).rounded())))
        let cacheKey = MenuBarBoltCacheKey(pixelRows: pixelRows, step: step)

        if let cached = cache[cacheKey] {
            return cached
        }

        let quantizedFillFraction = CGFloat(step) / CGFloat(pixelRows)
        let renderer = ImageRenderer(
            content: ProgressBoltIconView(
                fillFraction: quantizedFillFraction,
                size: size,
                style: .menuBarTemplate
            )
        )
        renderer.scale = scale

        let image = renderer.nsImage ?? NSImage(size: NSSize(width: size, height: size))
        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        cache[cacheKey] = image
        return image
    }
}

struct BoltIconView: View {
    let fillFraction: CGFloat
    let size: CGFloat

    var body: some View {
        ProgressBoltIconView(fillFraction: fillFraction, size: size, style: .app)
    }
}

struct MenuBarBoltIconView: View {
    let fillFraction: CGFloat

    var body: some View {
        Image(nsImage: MenuBarBoltRenderer.image(fillFraction: fillFraction, size: 15))
            .interpolation(.high)
            .accessibilityHidden(true)
    }
}
