import Foundation

// Сервис операций: данные с бэкенда через NetworkClient.
final class TransactionsService {

    // Общий экземпляр на всё приложение.
    static let shared = TransactionsService()

    private let client = NetworkClient.shared

    // Операции за период. Эндпоинт привязан к счёту,
    // поэтому берём основной (первый) счёт пользователя.
    func transactions(from startDate: Date, to endDate: Date) async throws -> [Transaction] {
        let accounts = try await BankAccountsService.shared.bankAccounts()
        guard let account = accounts.first else {
            return []
        }

        // endDate у нас — начало следующего дня; вычитаем секунду,
        // чтобы в "yyyy-MM-dd" не уехать на день вперёд.
        let inclusiveEnd = endDate.addingTimeInterval(-1)
        let queryItems = [
            URLQueryItem(name: "startDate", value: APIDate.dayString(from: startDate)),
            URLQueryItem(name: "endDate", value: APIDate.dayString(from: inclusiveEnd))
        ]

        let dtos: [TransactionResponseDTO] = try await client.request(
            path: "transactions/account/\(account.id)/period",
            queryItems: queryItems
        )
        return dtos.compactMap { dto in
            dto.toDomain()
        }
    }

    func createTransaction(_ transaction: Transaction) async throws {
        let requestBody = TransactionRequestDTO(transaction: transaction)
        let _: TransactionDTO = try await client.request(
            path: "transactions",
            method: "POST",
            body: requestBody
        )
    }

    func updateTransaction(_ transaction: Transaction) async throws {
        let requestBody = TransactionRequestDTO(transaction: transaction)
        let _: TransactionResponseDTO = try await client.request(
            path: "transactions/\(transaction.id)",
            method: "PUT",
            body: requestBody
        )
    }

    func deleteTransaction(id: Int) async throws {
        try await client.requestNoResponse(
            path: "transactions/\(id)",
            method: "DELETE"
        )
    }
}

