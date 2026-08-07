import Foundation
import SwiftData

// Локальное хранилище счетов. Создания и удаления здесь нет намеренно:
// в приложении счета не заводят и не удаляют, только правят баланс.
protocol BankAccountsStorage: Sendable {
    func getAll() async throws -> [BankAccount]
    func update(_ account: BankAccount) async throws
    func save(_ accounts: [BankAccount]) async throws
    // save работает upsert-ом, поэтому удалённый счёт сам из кеша не исчезнет —
    // без этого метода он остался бы там навсегда и всплывал офлайн.
    func delete(id: Int) async throws
    // Нужен при смене движка хранения: старую базу после переноса чистим.
    func clear() async throws
}

@Model
final class BankAccountEntity {

    @Attribute(.unique) var id: Int
    var name: String
    var emoji: String
    var balance: Decimal
    var currency: String

    init(account: BankAccount) {
        id = account.id
        name = account.name
        emoji = account.emoji
        balance = account.balance
        currency = account.currency
    }

    func apply(_ account: BankAccount) {
        name = account.name
        emoji = account.emoji
        balance = account.balance
        currency = account.currency
    }

    func toDomain() -> BankAccount {
        BankAccount(
            id: id,
            name: name,
            emoji: emoji,
            balance: balance,
            currency: currency
        )
    }
}

@ModelActor
actor SwiftDataBankAccountsStorage: BankAccountsStorage {

    init() throws {
        let url = URL.documentsDirectory.appending(path: "Accounts.store")
        let configuration = ModelConfiguration(url: url)
        let container = try ModelContainer(for: BankAccountEntity.self, configurations: configuration)
        self.init(modelContainer: container)
    }

    func getAll() throws -> [BankAccount] {
        let entities = try modelContext.fetch(FetchDescriptor<BankAccountEntity>())
        return entities.map { entity in
            entity.toDomain()
        }
    }

    func update(_ account: BankAccount) throws {
        try upsert(account)
        try modelContext.save()
    }

    func save(_ accounts: [BankAccount]) throws {
        for account in accounts {
            try upsert(account)
        }
        try modelContext.save()
    }

    func delete(id: Int) throws {
        guard let existing = try entity(id: id) else {
            return
        }
        modelContext.delete(existing)
        try modelContext.save()
    }

    func clear() throws {
        try modelContext.delete(model: BankAccountEntity.self)
        try modelContext.save()
    }

    private func upsert(_ account: BankAccount) throws {
        if let existing = try entity(id: account.id) {
            existing.apply(account)
        } else {
            modelContext.insert(BankAccountEntity(account: account))
        }
    }

    private func entity(id: Int) throws -> BankAccountEntity? {
        var descriptor = FetchDescriptor<BankAccountEntity>(
            predicate: #Predicate { entity in
                entity.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
