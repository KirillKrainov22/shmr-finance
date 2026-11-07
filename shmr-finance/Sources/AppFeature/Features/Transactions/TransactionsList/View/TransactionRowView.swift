import SwiftUI

struct TransactionRowView: View {
    struct Presentable: Identifiable {
        let id: Int
        let emoji: String
        let category: String
        let amount: String
    }

    let presentable: Presentable

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.separator), lineWidth: 1)
                    .scaledSquare(40)
                Text(presentable.emoji)
                    .scaledFont(size: 22)
            }
            .accessibilityHidden(true)
            Text(presentable.category)
                .scaledFont(size: 16, weight: .medium)
            Spacer()
            Text(presentable.amount)
                .scaledFont(size: 14, weight: .medium)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityHint(appString("Дважды коснитесь, чтобы изменить"))
    }
}
