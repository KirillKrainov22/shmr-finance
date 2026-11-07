import SwiftUI

// Модалка «Корректировка баланса»: сумма, дата/время, валюта, подтверждение/закрытие.
struct BalanceCorrectionContainer: View {

    let account: BankAccount
    let onConfirm: (Decimal) -> Void
    // Возвращает true, если удаление прошло — только тогда закрываем шторку.
    let onDelete: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var date = Date()
    @State private var deletedCount = 0

    init(
        account: BankAccount,
        onConfirm: @escaping (Decimal) -> Void,
        onDelete: @escaping () async -> Bool
    ) {
        self.account = account
        self.onConfirm = onConfirm
        self.onDelete = onDelete
        _amountText = State(initialValue: "\(account.balance)")
    }

    var body: some View {
        NavigationStack {
            BalanceCorrectionView(
                amount: $amountText,
                dateText: dateText,
                currencyName: currencyName,
                currencySymbol: currencySymbol,
                onDelete: delete
            )
            .onChange(of: amountText) { _, newValue in
                // Срабатывает и при вставке из буфера — чистим невалидные символы.
                let cleaned = filtered(newValue)
                if cleaned != newValue {
                    amountText = cleaned
                }
            }
            .environment(\.locale, LocalizationSettings.shared.locale)
            .scrollDismissesKeyboard(.interactively) // клавиатура прячется при свайпе
            .navigationTitle(appString("Корректировка баланса"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ToolbarConfirmButton(label: appString("Сохранить")) {
                        confirm()
                    }
                }
            }
            // Удаление — не успех, а исчезновение объекта, поэтому обычный удар.
            .hapticFeedback(.impact(weight: .medium, intensity: 1), trigger: deletedCount)
            .presentationDetents([.medium, .large])
        }
        .presentationBackground(Color(.systemBackground)) // белый фон, как у формы операции
    }

    private func delete() {
        Task {
            // Закрываем шторку только если удаление прошло успешно:
            // иначе пользователь не увидит, что помешало.
            if await onDelete() {
                deletedCount += 1
                dismiss()
            }
        }
    }

    private func confirm() {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        if let value = Decimal(string: normalized) {
            onConfirm(value)
        }
        dismiss()
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
        let locale = LocalizationSettings.shared.locale
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
            return appString("Руб.")
        default:
            return account.currency
        }
    }
}
