import SwiftUI

enum Theme {
    static let brand = Color(red: 0.26, green: 0.72, blue: 0.32)
    static let brandSoft = Color(red: 0.26, green: 0.72, blue: 0.32).opacity(0.14)
    static let warning = Color.orange
    static let danger = Color.red
    static let chartArea = Color(red: 0.26, green: 0.72, blue: 0.32)

    static func accent(for value: Double) -> Color {
        value > 0 ? brand : .secondary
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}
