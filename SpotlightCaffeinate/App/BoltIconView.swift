import AppKit
import SwiftUI

private struct BoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.64, y: rect.minY + rect.height * 0.06))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.58))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.58))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.94))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.84, y: rect.minY + rect.height * 0.40))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.60, y: rect.minY + rect.height * 0.40))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.minY + rect.height * 0.06))
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
    var boltCornerStroke: CGFloat { max(0.5, size * 0.04) }
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
        let cornerStrokeStyle = StrokeStyle(
            lineWidth: metrics.boltCornerStroke,
            lineCap: .round,
            lineJoin: .round
        )

        return ZStack {
            tileShape
                .fill(.white)

            if clampedFillFraction > 0 {
                clippedFillMask
                    .foregroundStyle(.black)
            }

            BoltShape()
                .padding(metrics.boltInset)
                .foregroundStyle(.black)

            BoltShape()
                .stroke(.black, style: cornerStrokeStyle)
                .padding(metrics.boltInset)

            if clampedFillFraction > 0 {
                ZStack {
                    BoltShape()
                        .padding(metrics.boltInset)
                        .foregroundStyle(.white)

                    BoltShape()
                        .stroke(.white, style: cornerStrokeStyle)
                        .padding(metrics.boltInset)
                }
                .mask(clippedFillMask)
            }

            tileShape
                .stroke(.black, lineWidth: metrics.strokeWidth)
        }
    }

    private var menuBarTemplateIcon: some View {
        let cornerStrokeStyle = StrokeStyle(
            lineWidth: metrics.boltCornerStroke,
            lineCap: .round,
            lineJoin: .round
        )

        return ZStack {
            if clampedFillFraction > 0 {
                clippedFillMask
                    .foregroundStyle(.black)
            }

            BoltShape()
                .padding(metrics.boltInset)
                .foregroundStyle(.black)

            BoltShape()
                .stroke(.black, style: cornerStrokeStyle)
                .padding(metrics.boltInset)

            if clampedFillFraction > 0 {
                ZStack {
                    BoltShape()
                        .padding(metrics.boltInset)
                        .foregroundStyle(.black)

                    BoltShape()
                        .stroke(.black, style: cornerStrokeStyle)
                        .padding(metrics.boltInset)
                }
                .mask(clippedFillMask)
                .blendMode(.destinationOut)
            }

            tileShape
                .stroke(.black, lineWidth: metrics.strokeWidth)
        }
        .compositingGroup()
    }
}

private struct RingProgressIconView: View {
    let fillFraction: CGFloat
    let size: CGFloat

    private var clampedFillFraction: CGFloat {
        min(max(fillFraction, 0), 1)
    }

    var body: some View {
        let trackWidth: CGFloat = max(1, size * 0.12)
        let inset = trackWidth / 2

        ZStack {
            Circle()
                .inset(by: inset)
                .stroke(.black.opacity(0.25), lineWidth: trackWidth)

            Circle()
                .inset(by: inset)
                .trim(from: 0, to: clampedFillFraction)
                .stroke(
                    .black,
                    style: StrokeStyle(lineWidth: trackWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            BoltShape()
                .padding(size * 0.30)
                .foregroundStyle(.black)

            BoltShape()
                .stroke(
                    .black,
                    style: StrokeStyle(
                        lineWidth: max(0.5, size * 0.04),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .padding(size * 0.30)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct CompactBoltIconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            BoltShape()
                .foregroundStyle(.black)

            BoltShape()
                .stroke(
                    .black,
                    style: StrokeStyle(
                        lineWidth: max(0.5, size * 0.06),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private enum MenuBarRendering {
    case boltFill
    case ring
    case compactBolt
}

private struct MenuBarRenderCacheKey: Hashable {
    let rendering: MenuBarRendering
    let pixelRows: Int
    let step: Int
}

@MainActor
private enum MenuBarGlyphRenderer {
    private static var cache: [MenuBarRenderCacheKey: NSImage] = [:]

    static func image(
        rendering: MenuBarRendering,
        fillFraction: CGFloat,
        size: CGFloat
    ) -> NSImage {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let pixelRows = max(1, Int(round(size * scale)))
        let step: Int
        switch rendering {
        case .boltFill, .ring:
            step = max(0, min(pixelRows, Int((min(max(fillFraction, 0), 1) * CGFloat(pixelRows)).rounded())))
        case .compactBolt:
            step = 0
        }
        let cacheKey = MenuBarRenderCacheKey(
            rendering: rendering,
            pixelRows: pixelRows,
            step: step
        )

        if let cached = cache[cacheKey] {
            return cached
        }

        let quantizedFillFraction = CGFloat(step) / CGFloat(pixelRows)
        let nsImage: NSImage
        switch rendering {
        case .boltFill:
            let renderer = ImageRenderer(
                content: ProgressBoltIconView(
                    fillFraction: quantizedFillFraction,
                    size: size,
                    style: .menuBarTemplate
                )
            )
            renderer.scale = scale
            nsImage = renderer.nsImage ?? NSImage(size: NSSize(width: size, height: size))
        case .ring:
            let renderer = ImageRenderer(
                content: RingProgressIconView(
                    fillFraction: quantizedFillFraction,
                    size: size
                )
            )
            renderer.scale = scale
            nsImage = renderer.nsImage ?? NSImage(size: NSSize(width: size, height: size))
        case .compactBolt:
            let renderer = ImageRenderer(
                content: CompactBoltIconView(size: size)
            )
            renderer.scale = scale
            nsImage = renderer.nsImage ?? NSImage(size: NSSize(width: size, height: size))
        }

        nsImage.size = NSSize(width: size, height: size)
        nsImage.isTemplate = true
        cache[cacheKey] = nsImage
        return nsImage
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
        Image(
            nsImage: MenuBarGlyphRenderer.image(
                rendering: .boltFill,
                fillFraction: fillFraction,
                size: 15
            )
        )
        .interpolation(.high)
        .accessibilityHidden(true)
    }
}

struct MenuBarGlyphView: View {
    let style: GlyphStyle
    let fillFraction: CGFloat
    let remainingTitle: String

    private static let standardSize: CGFloat = 15
    private static let compactBoltSize: CGFloat = 13

    var body: some View {
        switch style {
        case .boltFill:
            Image(
                nsImage: MenuBarGlyphRenderer.image(
                    rendering: .boltFill,
                    fillFraction: fillFraction,
                    size: Self.standardSize
                )
            )
            .interpolation(.high)
            .accessibilityHidden(true)

        case .ring:
            Image(
                nsImage: MenuBarGlyphRenderer.image(
                    rendering: .ring,
                    fillFraction: fillFraction,
                    size: Self.standardSize
                )
            )
            .interpolation(.high)
            .accessibilityHidden(true)

        case .text:
            HStack(spacing: 4) {
                Image(
                    nsImage: MenuBarGlyphRenderer.image(
                        rendering: .compactBolt,
                        fillFraction: 0,
                        size: Self.compactBoltSize
                    )
                )
                .interpolation(.high)

                Text(remainingTitle)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(remainingTitle))
        }
    }
}
