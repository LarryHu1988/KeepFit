import SwiftUI

struct SymbolBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                    .fill(tint.opacity(0.15))
            )
    }
}
