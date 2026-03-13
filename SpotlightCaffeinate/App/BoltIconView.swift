import SwiftUI

struct BoltIconView: View {
    var size: CGFloat

    var body: some View {
        Image("MenuBarBolt")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
