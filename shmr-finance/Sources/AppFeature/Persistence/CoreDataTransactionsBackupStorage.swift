import CoreData
import Foundation

// Запись очереди в базе CoreData. Аналог TransactionBackupEntity из SwiftData-версии.
final class CDTransactionBackup: NSManagedObject {

    static let entityName = "CDTransactionBackup"

    @NSManaged var id: Int64
    @NSManaged var action: String
    @NSManaged var accountId: Int64
    @NSManaged var categoryId: Int64
    @NSManaged var amount: NSDecimalNumber
    @NSManaged var transactionDate: Date
    @NSManaged var comment: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date

    static func entityDescription() -> NSEntityDescription {
        CoreDataModel.entity(
            name: entityName,
            managedObjectClass: CDTransactionBackup.self,
            attributes: [
                CoreDataModel.attribute("id", .integer64AttributeType),
                CoreDataModel.attribute("action", .stringAttributeType),
                CoreDataModel.attribute("accountId", .integer64AttributeType),
                CoreDataModel.attribute("categoryId", .integer64AttributeType),
                CoreDataModel.attribute("amount", .decimalAttributeType),
                CoreDataModel.attribute("transactionDate", .dateAttributeType),
                CoreDataModel.attribute("comment", .stringAttributeType, optional: true),
                CoreDataModel.attribute("createdAt", .dateAttributeType),
                CoreDataModel.attribute("updatedAt", .dateAttributeType)
            ],
            uniqueBy: "id"
        )
    }

    func apply(_ transaction: Transaction, action: TransactionBackupAction) {
        id = Int64(transaction.id)
        self.action = action.rawValue
        accountId = Int64(transaction.accountId)
        categoryId = Int64(transaction.categoryId)
        amount = NSDecimalNumber(decimal: transaction.amount)
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
            id: Int(id),
            accountId: Int(accountId),
            categoryId: Int(categoryId),
            amount: amount as Decimal,
            transactionDate: transactionDate,
            comment: comment,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        return TransactionBackupEntry(transaction: transaction, action: action)
    }
}

final class CoreDataTransactionsBackupStorage: TransactionsBackupStorage, @unchecked Sendable {

    private let stack: CoreDataStack

    init() throws {
        stack = try CoreDataStack(
            name: "TransactionsBackup",
            entity: CDTransactionBackup.entityDescription()
        )
    }

    func getAll() async throws -> [TransactionBackupEntry] {
        let context = stack.context
        return try await context.perform {
            try context.fetchAll(CDTransactionBackup.self, entityName: CDTransactionBackup.entityName)
                .compactMap { entity in
                    entity.toEntry()
                }
        }
    }

    // Правила слияния те же, что и в SwiftData-версии: одна операция — одна запись.
    func add(_ transaction: Transaction, action: TransactionBackupAction) async throws {
        let context = stack.context
        try await context.perform {
            let existing = try context.fetchOne(
                CDTransactionBackup.self,
                entityName: CDTransactionBackup.entityName,
                id: transaction.id
            )

            guard let existing else {
                let entity = context.insert(
                    CDTransactionBackup.self,
                    entityName: CDTransactionBackup.entityName
                )
                entity?.apply(transaction, action: action)
                try context.save()
                return
            }

            let existingAction = TransactionBackupAction(rawValue: existing.action) ?? .update

            switch (existingAction, action) {
            case (.create, .delete):
                // Сервер про эту операцию не знает: создали и тут же удалили офлайн.
                context.delete(existing)

            case (.create, _):
                // Операция всё ещё не создана на сервере — отправлять её надо
                // по-прежнему как создание.
                existing.apply(transaction, action: .create)

            default:
                existing.apply(transaction, action: action)
            }

            try context.save()
        }
    }

    func remove(ids: [Int]) async throws {
        guard ids.isEmpty == false else {
            return
        }
        let context = stack.context
        try await context.perform {
            for id in ids {
                let existing = try context.fetchOne(
                    CDTransactionBackup.self,
                    entityName: CDTransactionBackup.entityName,
                    id: id
                )
                if let existing {
                    context.delete(existing)
                }
            }
            try context.save()
        }
    }

    func clear() async throws {
        let context = stack.context
        try await context.perform {
            try context.deleteAll(entityName: CDTransactionBackup.entityName)
            try context.save()
        }
    }
}
