import SwiftUI

struct BalanceCorrectionView: View {
    let amount: Binding<String>
    let dateText: String
    let currencyName: String
    let currencySymbol: String
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            amountField

            infoRow(title: appString("Дата и время"), value: dateText)
            Divider()
            infoRow(title: appString("Валюта"), value: currencyName)

            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Text(appString("Удалить счёт"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }

            Spacer()
        }
    }

    // Сумма по центру, крупным rounded-шрифтом, с подчёркиванием. Тап — системная клавиатура.
    private var amountField: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                TextField("0", text: amount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: fieldWidth) // ширина по содержимому: сумма центрируется, пустое поле тапабельно
                Text(currencySymbol)
            }
            .scaledFont(size: 32, weight: .bold, design: .rounded)

            Rectangle()
                .fill(Color(.separator))
                .frame(width: 160, height: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // Ширина поля растёт по количеству символов, чтобы сумма оставалась по центру.
    private var fieldWidth: CGFloat {
        max(40, CGFloat(amount.wrappedValue.count) * 19 + 12)
    }
}
