import Foundation
import SwiftData

// Действие над операцией, которое ещё не доехало до сервера.
enum TransactionBackupAction: String {
    case create
    case update
    case delete
}

// Одна отложенная правка: сама операция и что с ней хотели сделать.
struct TransactionBackupEntry {
    let transaction: Transaction
    let action: TransactionBackupAction
}

// Очередь несинхронизированных изменений. По ТЗ каждая операция в ней
// уникальна по id — одна операция даёт одну запись, а не историю правок.
protocol TransactionsBackupStorage: Sendable {
    func getAll() async throws -> [TransactionBackupEntry]
    func add(_ transaction: Transaction, action: TransactionBackupAction) async throws
    func remove(ids: [Int]) async throws
    // Нужен при смене движка хранения: старую базу после переноса чистим.
    func clear() async throws
}

// Временные id для операций, созданных офлайн. Настоящий id выдаёт сервер,
// а до синхронизации операции нужен свой. Берём отрицательные: серверные
// всегда положительные, значит столкнуться они не могут, и по знаку id
// сразу видно, знает ли сервер об этой операции.
enum LocalTransactionID {

    private static let key = "lastLocalTransactionID"

    // Счётчик только убывает и никогда не переиспользует выданные значения.
    static func next() -> Int {
        let defaults = UserDefaults.standard
        let next = defaults.integer(forKey: key) - 1
        defaults.set(next, forKey: key)
        return next
    }

    static func isLocal(_ id: Int) -> Bool {
        id < 0
    }
}

@Model
final class TransactionBackupEntity {

    // Уникальность по id операции — прямое требование ТЗ.
    @Attribute(.unique) var id: Int
    var action: String
    var accountId: Int
    var categoryId: Int
    var amount: Decimal
    var transactionDate: Date
    var comment: String?
    var createdAt: Date
    var updatedAt: Date

    init(transaction: Transaction, action: TransactionBackupAction) {
        id = transaction.id
        self.action = action.rawValue
        accountId = transaction.accountId
        categoryId = transaction.categoryId
        amount = transaction.amount
        transactionDate = transaction.transactionDate
        comment = transaction.comment
        createdAt = transaction.createdAt
        updatedAt = transaction.updatedAt
    }

    func apply(_ transaction: Transaction, action: TransactionBackupAction) {
        self.action = action.rawValue
        accountId = transaction.accountId
        categoryId = transaction.categoryId
        amount = transaction.amount
        transactionDate = transaction.transactionDate
        comment = transaction.comment
        createdAt = transaction.createdAt
        updatedAt = transaction.updatedAt
    }

    func toEntry() -> TransactionBackupEntry? {
        guard let action = TransactionBackupAction(rawValue: action) else {
            return nil
        }
        let transaction = Transaction(
            id: id,
            accountId: accountId,
            categoryId: categoryId,
            amount: amount,
            transactionDate: transactionDate,
            comment: comment,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        return TransactionBackupEntry(transaction: transaction, action: action)
    }
}

@ModelActor
actor SwiftDataTransactionsBackupStorage: TransactionsBackupStorage {

    init() throws {
        let url = URL.documentsDirectory.appending(path: "TransactionsBackup.store")
        let configuration = ModelConfiguration(url: url)
        let container = try ModelContainer(
            for: TransactionBackupEntity.self,
            configurations: configuration
        )
        self.init(modelContainer: container)
    }

    func getAll() throws -> [TransactionBackupEntry] {
        let entities = try modelContext.fetch(FetchDescriptor<TransactionBackupEntity>())
        return entities.compactMap { entity in
            entity.toEntry()
        }
    }

    // Здесь живут правила слияния. Одна операция — одна запись,
    // поэтому новое действие не добавляется, а поглощает предыдущее.
    func add(_ transaction: Transaction, action: TransactionBackupAction) throws {
        guard let existing = try entity(id: transaction.id) else {
            modelContext.insert(TransactionBackupEntity(transaction: transaction, action: action))
            try modelContext.save()
            return
        }

        // Битое значение в базе трактуем как обычную правку — так безопаснее,
        // чем потерять запись.
        let existingAction = TransactionBackupAction(rawValue: existing.action) ?? .update

        switch (existingAction, action) {
        case (.create, .delete):
            // Сервер про эту операцию вообще не знает: создали и тут же удалили офлайн.
            // Отправлять нечего — выбрасываем запись целиком.
            modelContext.delete(existing)

        case (.create, _):
            // Операция всё ещё не создана на сервере. Данные обновляем,
            // но отправлять её надо по-прежнему как создание, а не как правку.
            existing.apply(transaction, action: .create)

        default:
            existing.apply(transaction, action: action)
        }

        try modelContext.save()
    }

    func remove(ids: [Int]) throws {
        guard ids.isEmpty == false else {
            return
        }
        for id in ids {
            if let existing = try entity(id: id) {
                modelContext.delete(existing)
            }
        }
        try modelContext.save()
    }

    func clear() throws {
        try modelContext.delete(model: TransactionBackupEntity.self)
        try modelContext.save()
    }

    private func entity(id: Int) throws -> TransactionBackupEntity? {
        var descriptor = FetchDescriptor<TransactionBackupEntity>(
            predicate: #Predicate { entity in
                entity.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
