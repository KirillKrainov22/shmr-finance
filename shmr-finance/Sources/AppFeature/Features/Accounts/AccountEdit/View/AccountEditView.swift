import SwiftUI

struct AccountEditView: View {
    let balance: Binding<String>
    let name: Binding<String>
    let emoji: Binding<String>
    let emojiPlaceholder: String

    var body: some View {
        VStack(spacing: 0) {
            balanceField

            TextField(appString("Название"), text: name)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            Divider()

            HStack {
                Text(appString("Эмодзи"))
                Spacer()
                TextField(emojiPlaceholder, text: emoji)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            // Валюта только рублёвая, поэтому строка справочная, без выбора.
            HStack {
                Text(appString("Валюта"))
                Spacer()
                Text(appString("Руб."))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Spacer()
        }
    }

    // Начальный баланс — крупно по центру, как сумма в остальных формах.
    private var balanceField: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                TextField("0", text: balance)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: fieldWidth)
                Text("₽")
                    .foregroundStyle(.secondary)
            }
            .scaledFont(size: 32, weight: .bold, design: .rounded)

            Rectangle()
                .fill(Color(.separator))
                .frame(width: 160, height: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // Ширина поля растёт по количеству символов, чтобы сумма оставалась по центру.
    private var fieldWidth: CGFloat {
        max(40, CGFloat(balance.wrappedValue.count) * 19 + 12)
    }
}
