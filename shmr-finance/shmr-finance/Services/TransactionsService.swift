import Foundation

// Сервис операций: данные с бэкенда через NetworkClient, копия — в локальном хранилище.
final class TransactionsService {

    // Общий экземпляр на всё приложение.
    static let shared = TransactionsService()

    private let client = NetworkClient.shared
    private let storage = LocalStorages.transactions

    // Операции за период. Эндпоинт привязан к счёту,
    // поэтому берём основной (первый) счёт пользователя.
    func transactions(from startDate: Date, to endDate: Date) async throws -> [Transaction] {
        do {
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
            let transactions = dtos.compactMap { dto in
                dto.toDomain()
            }
            try? await storage?.save(transactions)
            return transactions
        } catch {
            return try await cachedTransactions(from: startDate, to: endDate, networkError: error)
        }
    }

    func createTransaction(_ transaction: Transaction) async throws {
        let requestBody = TransactionRequestDTO(transaction: transaction)
        let dto: TransactionDTO = try await client.request(
            path: "transactions",
            method: "POST",
            body: requestBody
        )
        // Локально сохраняем ответ сервера, а не то, что отправляли:
        // настоящий id операции известен только серверу.
        if let created = dto.toDomain() {
            try? await storage?.create(created)
        }
    }

    func updateTransaction(_ transaction: Transaction) async throws {
        let requestBody = TransactionRequestDTO(transaction: transaction)
        let dto: TransactionResponseDTO = try await client.request(
            path: "transactions/\(transaction.id)",
            method: "PUT",
            body: requestBody
        )
        if let updated = dto.toDomain() {
            try? await storage?.update(updated)
        }
    }

    func deleteTransaction(id: Int) async throws {
        try await client.requestNoResponse(
            path: "transactions/\(id)",
            method: "DELETE"
        )
        try? await storage?.delete(id: id)
    }

    // Сеть не ответила — отдаём последнее, что знаем.
    private func cachedTransactions(
        from startDate: Date,
        to endDate: Date,
        networkError: Error
    ) async throws -> [Transaction] {
        let cached = (try? await storage?.getAll()) ?? []

        // Пустое хранилище означает, что мы вообще ничего не загружали, —
        // тут честнее показать ошибку, чем сделать вид, что операций нет.
        // А вот пустая выборка за конкретный день — нормальный ответ.
        guard cached.isEmpty == false else {
            throw networkError
        }

        return cached.filter { transaction in
            transaction.transactionDate >= startDate && transaction.transactionDate < endDate
        }
    }
}

