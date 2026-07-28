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
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarConfirmButton(label: "Сохранить") {
                        confirm()
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .presentationBackground(Color(.systemBackground)) // белый фон, как у формы операции
    }

    // Сумма по центру, крупным rounded-шрифтом, с подчёркиванием. Тап — системная клавиатура.
    private var amountField: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: fieldWidth) // ширина по содержимому: сумма центрируется, пустое поле тапабельно
                    .onChange(of: amountText) { _, newValue in
                        // Срабатывает и при вставке из буфера — чистим невалидные символы.
                        let cleaned = filtered(newValue)
                        if cleaned != newValue {
                            amountText = cleaned
                        }
                    }
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


    private func confirm() {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        if let value = Decimal(string: normalized) {
            onConfirm(value)
        }
        dismiss()
    }

    // Ширина поля растёт по количеству символов, чтобы сумма оставалась по центру.
    private var fieldWidth: CGFloat {
        return max(40, CGFloat(amountText.count) * 19 + 12)
    }

    // Оставляем цифры, один разделитель и максимум 2 знака после него.
    private func filtered(_ input: String) -> String {
        var result = ""
        var hasSeparator = false
        var decimalCount = 0
        for character in input {
            if character.isNumber {
                if hasSeparator {
                    if decimalCount < 2 {
                        result.append(character)
                        decimalCount += 1
                    }
                } else {
                    result.append(character)
                }
            } else if (character == "." || character == ",") && hasSeparator == false {
                result.append(character)
                hasSeparator = true
            }
        }
        return result
    }

    private var dateText: String {
        // «20 февраля, 23:42» — дата и время через запятую (системный формат вставляет «в»).
        let locale = Locale(identifier: "ru_RU")
        let day = date.formatted(
            .dateTime.day().month(.wide).locale(locale)
        )
        let time = date.formatted(
            .dateTime.hour().minute().locale(locale)
        )
        return "\(day), \(time)"
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

