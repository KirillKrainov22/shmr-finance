import Foundation
import SwiftData

// Очередь несинхронизированных изменений счёта. Действия здесь не нужны:
// счета в приложении не создают и не удаляют, единственная правка — новое
// состояние счёта, поэтому храним просто сам счёт. Уникальность по id.
protocol BankAccountsBackupStorage: Sendable {
    func getAll() async throws -> [BankAccount]
    func add(_ account: BankAccount) async throws
    func remove(ids: [Int]) async throws
    // Нужен при смене движка хранения: старую базу после переноса чистим.
    func clear() async throws
}

@Model
final class BankAccountBackupEntity {

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
actor SwiftDataBankAccountsBackupStorage: BankAccountsBackupStorage {

    init() throws {
        let url = URL.documentsDirectory.appending(path: "AccountsBackup.store")
        let configuration = ModelConfiguration(url: url)
        let container = try ModelContainer(
            for: BankAccountBackupEntity.self,
            configurations: configuration
        )
        self.init(modelContainer: container)
    }

    func getAll() throws -> [BankAccount] {
        let entities = try modelContext.fetch(FetchDescriptor<BankAccountBackupEntity>())
        return entities.map { entity in
            entity.toDomain()
        }
    }

    // Новое состояние счёта поглощает предыдущее: серверу важно только то,
    // каким счёт должен стать в итоге.
    func add(_ account: BankAccount) throws {
        if let existing = try entity(id: account.id) {
            existing.apply(account)
        } else {
            modelContext.insert(BankAccountBackupEntity(account: account))
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
        try modelContext.delete(model: BankAccountBackupEntity.self)
        try modelContext.save()
    }

    private func entity(id: Int) throws -> BankAccountBackupEntity? {
        var descriptor = FetchDescriptor<BankAccountBackupEntity>(
            predicate: #Predicate { entity in
                entity.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
