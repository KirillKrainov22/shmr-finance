import CoreData
import Foundation

// Операция в базе CoreData. Аналог TransactionEntity из SwiftData-версии.
// Decimal в CoreData хранится как NSDecimalNumber, поэтому здесь он такого типа.
final class CDTransaction: NSManagedObject {

    static let entityName = "CDTransaction"

    @NSManaged var id: Int64
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
            managedObjectClass: CDTransaction.self,
            attributes: [
                CoreDataModel.attribute("id", .integer64AttributeType),
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

    func apply(_ transaction: Transaction) {
        id = Int64(transaction.id)
        accountId = Int64(transaction.accountId)
        categoryId = Int64(transaction.categoryId)
        amount = NSDecimalNumber(decimal: transaction.amount)
        transactionDate = transaction.transactionDate
        comment = transaction.comment
        createdAt = transaction.createdAt
        updatedAt = transaction.updatedAt
    }

    func toDomain() -> Transaction {
        Transaction(
            id: Int(id),
            accountId: Int(accountId),
            categoryId: Int(categoryId),
            amount: amount as Decimal,
            transactionDate: transactionDate,
            comment: comment,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

final class CoreDataTransactionsStorage: TransactionsStorage, @unchecked Sendable {

    private let stack: CoreDataStack

    init() throws {
        stack = try CoreDataStack(name: "Transactions", entity: CDTransaction.entityDescription())
    }

    func getAll() async throws -> [Transaction] {
        let context = stack.context
        return try await context.perform {
            try context.fetchAll(CDTransaction.self, entityName: CDTransaction.entityName)
                .map { entity in
                    entity.toDomain()
                }
        }
    }

    func create(_ transaction: Transaction) async throws {
        try await save([transaction])
    }

    func update(_ transaction: Transaction) async throws {
        try await save([transaction])
    }

    func delete(id: Int) async throws {
        let context = stack.context
        try await context.perform {
            guard let existing = try context.fetchOne(
                CDTransaction.self,
                entityName: CDTransaction.entityName,
                id: id
            ) else {
                return
            }
            context.delete(existing)
            try context.save()
        }
    }

    func save(_ transactions: [Transaction]) async throws {
        let context = stack.context
        try await context.perform {
            for transaction in transactions {
                // Создание и изменение — одно и то же: должна остаться
                // ровно одна строка с этим id.
                let existing = try context.fetchOne(
                    CDTransaction.self,
                    entityName: CDTransaction.entityName,
                    id: transaction.id
                )
                let entity = existing ?? context.insert(
                    CDTransaction.self,
                    entityName: CDTransaction.entityName
                )
                entity?.apply(transaction)
            }
            try context.save()
        }
    }

    func clear() async throws {
        let context = stack.context
        try await context.perform {
            try context.deleteAll(entityName: CDTransaction.entityName)
            try context.save()
        }
    }
}
