import PhosphorSwift
import SwiftUI

struct AppIconBadge: View {
    let icon: Ph
    let tint: Color
    let size: CGFloat
    var weight: Ph.IconWeight = .duotone

    var body: some View {
        icon.weight(weight)
            .color(tint)
            .aspectRatio(contentMode: .fit)
            .frame(width: size * 0.56, height: size * 0.56)
            .padding(size * 0.22)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                    .fill(tint.opacity(0.16))
            )
    }
}
