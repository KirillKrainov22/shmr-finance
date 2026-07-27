import CoreData
import Foundation

// Запись очереди счетов в базе CoreData. Аналог BankAccountBackupEntity из SwiftData-версии.
final class CDBankAccountBackup: NSManagedObject {

    static let entityName = "CDBankAccountBackup"

    @NSManaged var id: Int64
    @NSManaged var name: String
    @NSManaged var emoji: String
    @NSManaged var balance: NSDecimalNumber
    @NSManaged var currency: String

    static func entityDescription() -> NSEntityDescription {
        CoreDataModel.entity(
            name: entityName,
            managedObjectClass: CDBankAccountBackup.self,
            attributes: [
                CoreDataModel.attribute("id", .integer64AttributeType),
                CoreDataModel.attribute("name", .stringAttributeType),
                CoreDataModel.attribute("emoji", .stringAttributeType),
                CoreDataModel.attribute("balance", .decimalAttributeType),
                CoreDataModel.attribute("currency", .stringAttributeType)
            ],
            uniqueBy: "id"
        )
    }

    func apply(_ account: BankAccount) {
        id = Int64(account.id)
        name = account.name
        emoji = account.emoji
        balance = NSDecimalNumber(decimal: account.balance)
        currency = account.currency
    }

    func toDomain() -> BankAccount {
        BankAccount(
            id: Int(id),
            name: name,
            emoji: emoji,
            balance: balance as Decimal,
            currency: currency
        )
    }
}

final class CoreDataBankAccountsBackupStorage: BankAccountsBackupStorage, @unchecked Sendable {

    private let stack: CoreDataStack

    init() throws {
        stack = try CoreDataStack(
            name: "AccountsBackup",
            entity: CDBankAccountBackup.entityDescription()
        )
    }

    func getAll() async throws -> [BankAccount] {
        let context = stack.context
        return try await context.perform {
            try context.fetchAll(CDBankAccountBackup.self, entityName: CDBankAccountBackup.entityName)
                .map { entity in
                    entity.toDomain()
                }
        }
    }

    func add(_ account: BankAccount) async throws {
        let context = stack.context
        try await context.perform {
            let existing = try context.fetchOne(
                CDBankAccountBackup.self,
                entityName: CDBankAccountBackup.entityName,
                id: account.id
            )
            let entity = existing ?? context.insert(
                CDBankAccountBackup.self,
                entityName: CDBankAccountBackup.entityName
            )
            entity?.apply(account)
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
                    CDBankAccountBackup.self,
                    entityName: CDBankAccountBackup.entityName,
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
            try context.deleteAll(entityName: CDBankAccountBackup.entityName)
            try context.save()
        }
    }
}
