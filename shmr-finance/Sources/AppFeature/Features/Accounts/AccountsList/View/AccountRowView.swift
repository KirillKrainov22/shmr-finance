import SwiftUI

struct AccountRowView: View {
    let account: BankAccount

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.separator), lineWidth: 1)
                    .scaledSquare(40)
                Text(account.emoji)
                    .scaledFont(size: 22)
            }
            // Эмодзи — украшение, его название только зашумит озвучку.
            .accessibilityHidden(true)
            Text(account.name)
                .scaledFont(size: 16, weight: .medium)
            Spacer()
            // Валюта своя у каждого счёта, а не общая для экрана: иначе
            // рублёвый счёт показывался бы со знаком выбранного долларового.
            Text(account.balance, format: .currency(code: account.currency).precision(.fractionLength(0...2)))
                .scaledFont(size: 14, weight: .medium)
        }
        .padding(.vertical, 3)
        // Без этого строка читается тремя отдельными остановками вместо одной фразы.
        .accessibilityElement(children: .combine)
        .accessibilityHint(appString("Дважды коснитесь, чтобы изменить баланс"))
    }
}
