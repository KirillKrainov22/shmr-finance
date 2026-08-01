import Foundation
import Observation

// Мозг формы создания счёта.
@Observable
final class AccountFormViewModel {

    // Приложение считает и показывает суммы только в рублях: код валюты
    // зашит в форматирование на всех экранах. Пока это так, давать выбор
    // валюты нельзя — общий баланс сложил бы рубли с долларами.
    static let currency = "RUB"

    // Эмодзи по умолчанию — то же, что подставляет бэкенд.
    static let defaultEmoji = "💵"

    var name = ""
    var emoji = ""
    var balanceText = ""

    var isLoading = false
    var showError = false
    var errorMessage = ""

    private let service = BankAccountsService.shared

    // Название и баланс обязательны, эмодзи нет — за него подставим стандартное.
    var isValid: Bool {
        trimmedName.isEmpty == false && parsedBalance != nil
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Баланс из текста в Decimal (nil, если пусто или мусор).
    var parsedBalance: Decimal? {
        let normalized = balanceText.replacingOccurrences(of: ",", with: ".")
        guard normalized.isEmpty == false else {
            return nil
        }
        return Decimal(string: normalized)
    }

    // Создание счёта. Возвращает true при успехе.
    @discardableResult
    func save() async -> Bool {
        guard let balance = parsedBalance, trimmedName.isEmpty == false else {
            return false
        }

        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let emojiOrDefault = trimmedEmoji.isEmpty ? Self.defaultEmoji : trimmedEmoji

        isLoading = true
        defer {
            isLoading = false
        }

        do {
            try await service.createAccount(
                name: trimmedName,
                emoji: emojiOrDefault,
                balance: balance,
                currency: Self.currency
            )
            return true
        } catch {
            guard isCancellationError(error) == false else {
                return false
            }
            errorMessage = userErrorMessage(from: error)
            showError = true
            return false
        }
    }
}
