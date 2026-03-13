import AppKit
import SwiftUI

private enum BoltIconAsset {
    static let template: NSImage = {
        guard let image = NSImage(named: "MenuBarBolt") else {
            return NSImage()
        }

        let copy = (image.copy() as? NSImage) ?? image
        copy.isTemplate = true
        return copy
    }()
}

struct BoltIconView: View {
    var size: CGFloat

    var body: some View {
        Image(nsImage: BoltIconAsset.template)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
