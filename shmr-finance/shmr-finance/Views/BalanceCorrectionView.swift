import SwiftUI

// Модалка «Корректировка баланса»: сумма, дата/время, валюта, подтверждение/закрытие.
struct BalanceCorrectionView: View {

    let account: BankAccount
    let onConfirm: (Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var date = Date()

    init(account: BankAccount, onConfirm: @escaping (Decimal) -> Void) {
        self.account = account
        self.onConfirm = onConfirm
        _amountText = State(initialValue: "\(account.balance)")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                amountField

                infoRow(title: "Дата и время", value: dateText)
                Divider()
                infoRow(title: "Валюта", value: currencyName)

                Spacer()
            }
            .environment(\.locale, Locale(identifier: "ru_RU"))
            .scrollDismissesKeyboard(.interactively) // клавиатура прячется при свайпе
            .navigationTitle("Корректировка баланса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    circleToolbarButton(systemName: "xmark", foreground: .primary, background: Color(.systemGray5)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    circleToolbarButton(systemName: "checkmark", foreground: .white, background: .accentColor) {
                        confirm()
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // Сумма по центру, крупным rounded-шрифтом, с подчёркиванием. Тап — системная клавиатура.
    private var amountField: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                Text(currencySymbol)
            }
            .font(.system(size: 32, weight: .bold, design: .rounded))

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

    private func circleToolbarButton(
        systemName: String,
        foreground: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 32, height: 32)
                .background(Circle().fill(background))
        }
        .buttonStyle(.plain)
    }

    private func confirm() {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        if let value = Decimal(string: normalized) {
            onConfirm(value)
        }
        dismiss()
    }

    private var dateText: String {
        date.formatted(
            .dateTime
                .day()
                .month(.wide)
                .hour()
                .minute()
                .locale(Locale(identifier: "ru_RU"))
        )
    }

    private var currencySymbol: String {
        switch account.currency {
        case "RUB":
            return "₽"
        case "USD":
            return "$"
        case "EUR":
            return "€"
        default:
            return account.currency
        }
    }

    private var currencyName: String {
        switch account.currency {
        case "RUB":
            return "Руб."
        default:
            return account.currency
        }
    }
}

