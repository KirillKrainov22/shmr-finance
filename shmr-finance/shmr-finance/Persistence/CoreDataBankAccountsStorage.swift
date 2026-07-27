import CoreData
import Foundation

// Счёт в базе CoreData. Аналог BankAccountEntity из SwiftData-версии.
final class CDBankAccount: NSManagedObject {

    static let entityName = "CDBankAccount"

    @NSManaged var id: Int64
    @NSManaged var name: String
    @NSManaged var emoji: String
    @NSManaged var balance: NSDecimalNumber
    @NSManaged var currency: String

    static func entityDescription() -> NSEntityDescription {
        CoreDataModel.entity(
            name: entityName,
            managedObjectClass: CDBankAccount.self,
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

final class CoreDataBankAccountsStorage: BankAccountsStorage, @unchecked Sendable {

    private let stack: CoreDataStack

    init() throws {
        stack = try CoreDataStack(name: "Accounts", entity: CDBankAccount.entityDescription())
    }

    func getAll() async throws -> [BankAccount] {
        let context = stack.context
        return try await context.perform {
            try context.fetchAll(CDBankAccount.self, entityName: CDBankAccount.entityName)
                .map { entity in
                    entity.toDomain()
                }
        }
    }

    func update(_ account: BankAccount) async throws {
        try await save([account])
    }

    func save(_ accounts: [BankAccount]) async throws {
        let context = stack.context
        try await context.perform {
            for account in accounts {
                let existing = try context.fetchOne(
                    CDBankAccount.self,
                    entityName: CDBankAccount.entityName,
                    id: account.id
                )
                let entity = existing ?? context.insert(
                    CDBankAccount.self,
                    entityName: CDBankAccount.entityName
                )
                entity?.apply(account)
            }
            try context.save()
        }
    }

    func clear() async throws {
        let context = stack.context
        try await context.perform {
            try context.deleteAll(entityName: CDBankAccount.entityName)
            try context.save()
        }
    }
}
