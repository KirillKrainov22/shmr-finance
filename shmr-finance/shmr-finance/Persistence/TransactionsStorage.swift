import Foundation
import SwiftData

// Локальное хранилище операций. Четыре метода из ТЗ плюс запись пачкой —
// она нужна, чтобы сложить ответ сервера за период одним заходом.
protocol TransactionsStorage: Sendable {
    func getAll() async throws -> [Transaction]
    func create(_ transaction: Transaction) async throws
    func update(_ transaction: Transaction) async throws
    func delete(id: Int) async throws
    func save(_ transactions: [Transaction]) async throws
}

// Строка таблицы операций. Отдельный тип от доменной Transaction:
// структура не должна знать про формат хранения.
@Model
final class TransactionEntity {

    @Attribute(.unique) var id: Int
    var accountId: Int
    var categoryId: Int
    var amount: Decimal
    var transactionDate: Date
    var comment: String?
    var createdAt: Date
    var updatedAt: Date

    init(transaction: Transaction) {
        id = transaction.id
        accountId = transaction.accountId
        categoryId = transaction.categoryId
        amount = transaction.amount
        transactionDate = transaction.transactionDate
        comment = transaction.comment
        createdAt = transaction.createdAt
        updatedAt = transaction.updatedAt
    }

    // Перезаписать существующую строку. id не трогаем — по нему её и нашли.
    func apply(_ transaction: Transaction) {
        accountId = transaction.accountId
        categoryId = transaction.categoryId
        amount = transaction.amount
        transactionDate = transaction.transactionDate
        comment = transaction.comment
        createdAt = transaction.createdAt
        updatedAt = transaction.updatedAt
    }

    func toDomain() -> Transaction {
        Transaction(
            id: id,
            accountId: accountId,
            categoryId: categoryId,
            amount: amount,
            transactionDate: transactionDate,
            comment: comment,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@ModelActor
actor SwiftDataTransactionsStorage: TransactionsStorage {

    init() throws {
        let url = URL.documentsDirectory.appending(path: "Transactions.store")
        let configuration = ModelConfiguration(url: url)
        let container = try ModelContainer(for: TransactionEntity.self, configurations: configuration)
        self.init(modelContainer: container)
    }

    func getAll() throws -> [Transaction] {
        let entities = try modelContext.fetch(FetchDescriptor<TransactionEntity>())
        return entities.map { entity in
            entity.toDomain()
        }
    }

    func create(_ transaction: Transaction) throws {
        try upsert(transaction)
        try modelContext.save()
    }

    func update(_ transaction: Transaction) throws {
        try upsert(transaction)
        try modelContext.save()
    }

    func delete(id: Int) throws {
        guard let existing = try entity(id: id) else {
            return
        }
        modelContext.delete(existing)
        try modelContext.save()
    }

    func save(_ transactions: [Transaction]) throws {
        for transaction in transactions {
            try upsert(transaction)
        }
        try modelContext.save()
    }

    // Создание и изменение отличаются только намерением: в обоих случаях
    // нужна ровно одна строка с этим id.
    private func upsert(_ transaction: Transaction) throws {
        if let existing = try entity(id: transaction.id) {
            existing.apply(transaction)
        } else {
            modelContext.insert(TransactionEntity(transaction: transaction))
        }
    }

    private func entity(id: Int) throws -> TransactionEntity? {
        var descriptor = FetchDescriptor<TransactionEntity>(
            predicate: #Predicate { entity in
                entity.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
