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
    let style: BoltIconStyle

    var cornerRadius: CGFloat {
        switch style {
        case .app: return size * 0.30
        case .menuBarTemplate: return size * 0.45
        }
    }
    var strokeWidth: CGFloat { max(1.5, size * 0.18) }
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

private enum BoltIconStyle: Sendable {
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
        BoltIconMetrics(size: size, style: style)
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
                .stroke(
                    .black,
                    style: StrokeStyle(
                        lineWidth: metrics.strokeWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
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
                .stroke(
                    .black,
                    style: StrokeStyle(
                        lineWidth: metrics.strokeWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
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

private struct ModeDotsView: View {
    let mode: PowerMode
    let glyphSize: CGFloat

    private var dotCount: Int {
        switch mode {
        case .display: return 1
        case .system: return 2
        case .full: return 3
        }
    }

    var body: some View {
        let dotDiameter = max(1, glyphSize * 0.18)
        HStack(spacing: glyphSize * 0.10) {
            ForEach(0 ..< dotCount, id: \.self) { _ in
                Circle()
                    .frame(width: dotDiameter, height: dotDiameter)
                    .foregroundStyle(.black)
            }
        }
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
    let mode: PowerMode?
}

@MainActor
private enum MenuBarGlyphRenderer {
    private static var cache: [MenuBarRenderCacheKey: NSImage] = [:]

    private static let dotStripHeightFraction: CGFloat = 0.22
    private static let dotStripGapFraction: CGFloat = 0.06

    static func image(
        rendering: MenuBarRendering,
        fillFraction: CGFloat,
        mode: PowerMode?,
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
            step: step,
            mode: mode
        )

        if let cached = cache[cacheKey] {
            return cached
        }

        let quantizedFillFraction = CGFloat(step) / CGFloat(pixelRows)
        let glyph = glyphView(
            rendering: rendering,
            fillFraction: quantizedFillFraction,
            size: size
        )
        let composed = composedView(glyph: glyph, mode: mode, glyphSize: size)
        let totalHeight = mode == nil
            ? size
            : size + (size * (dotStripHeightFraction + dotStripGapFraction))

        let renderer = ImageRenderer(content: composed)
        renderer.scale = scale
        let nsImage = renderer.nsImage ?? NSImage(size: NSSize(width: size, height: totalHeight))

        nsImage.size = NSSize(width: size, height: totalHeight)
        nsImage.isTemplate = true
        cache[cacheKey] = nsImage
        return nsImage
    }

    @ViewBuilder
    private static func glyphView(
        rendering: MenuBarRendering,
        fillFraction: CGFloat,
        size: CGFloat
    ) -> some View {
        switch rendering {
        case .boltFill:
            ProgressBoltIconView(
                fillFraction: fillFraction,
                size: size,
                style: .menuBarTemplate
            )
        case .ring:
            RingProgressIconView(
                fillFraction: fillFraction,
                size: size
            )
        case .compactBolt:
            CompactBoltIconView(size: size)
        }
    }

    @ViewBuilder
    private static func composedView<Inner: View>(
        glyph: Inner,
        mode: PowerMode?,
        glyphSize: CGFloat
    ) -> some View {
        if let mode {
            VStack(spacing: glyphSize * dotStripGapFraction) {
                glyph
                ModeDotsView(mode: mode, glyphSize: glyphSize)
                    .frame(height: glyphSize * dotStripHeightFraction)
            }
        } else {
            glyph
        }
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
                mode: nil,
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
    let mode: PowerMode?
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
                    mode: mode,
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
                    mode: mode,
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
                        mode: mode,
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
