import Foundation

// Движок локального хранения. Значение приходит из системных настроек (Settings Bundle).
enum StorageEngine: String {
    case swiftData
    case coreData
}

// Единственное место, где приложение решает, какой реализацией хранилища пользоваться.
enum LocalStorages {

    // Ключ переключателя в Settings.app — должен совпадать с Root.plist.
    private static let selectedKey = "storage_engine"
    // Каким движком данные записаны сейчас. Нужен, чтобы заметить смену.
    private static let activeKey = "active_storage_engine"

    // Что выбрано в настройках. Пока пользователь туда не заходил, ключа нет —
    // отсюда и значение по умолчанию.
    static var selectedEngine: StorageEngine {
        let raw = UserDefaults.standard.string(forKey: selectedKey) ?? ""
        return StorageEngine(rawValue: raw) ?? .swiftData
    }

    private static var activeEngine: StorageEngine {
        let raw = UserDefaults.standard.string(forKey: activeKey) ?? ""
        return StorageEngine(rawValue: raw) ?? .swiftData
    }

    // nil, если базу не удалось открыть (нет места, битый файл).
    // Тогда приложение работает без кеша, но не падает.
    static let categories: CategoriesStorage? = makeCategories(selectedEngine)
    static let transactions: TransactionsStorage? = makeTransactions(selectedEngine)
    static let accounts: BankAccountsStorage? = makeAccounts(selectedEngine)
    static let transactionsBackup: TransactionsBackupStorage? = makeTransactionsBackup(selectedEngine)
    static let accountsBackup: BankAccountsBackupStorage? = makeAccountsBackup(selectedEngine)

    // MARK: - Миграция

    // Вызывается на старте приложения до показа экранов. Если движок в настройках
    // сменили, переносим данные в новое хранилище и чистим старое.
    static func migrateIfNeeded() async {
        let from = activeEngine
        let to = selectedEngine

        guard from != to else {
            return
        }

        // Везде один порядок: сначала копируем, и только при успехе чистим источник.
        // Если копирование сорвалось, старые данные остаются на месте.

        if let source = makeCategories(from), let destination = makeCategories(to) {
            do {
                try await destination.replaceAll(with: source.getAll())
                try? await source.clear()
            } catch {
                return
            }
        }

        if let source = makeTransactions(from), let destination = makeTransactions(to) {
            do {
                try await destination.save(source.getAll())
                try? await source.clear()
            } catch {
                return
            }
        }

        if let source = makeAccounts(from), let destination = makeAccounts(to) {
            do {
                try await destination.save(source.getAll())
                try? await source.clear()
            } catch {
                return
            }
        }

        if let source = makeTransactionsBackup(from), let destination = makeTransactionsBackup(to) {
            do {
                for entry in try await source.getAll() {
                    try await destination.add(entry.transaction, action: entry.action)
                }
                try? await source.clear()
            } catch {
                return
            }
        }

        if let source = makeAccountsBackup(from), let destination = makeAccountsBackup(to) {
            do {
                for account in try await source.getAll() {
                    try await destination.add(account)
                }
                try? await source.clear()
            } catch {
                return
            }
        }

        // Отмечаем смену только после того, как всё перенеслось. Если что-то упало
        // и мы вышли раньше, на следующем старте миграция повторится.
        UserDefaults.standard.set(to.rawValue, forKey: activeKey)
    }

    // MARK: - Создание хранилищ

    private static func makeCategories(_ engine: StorageEngine) -> CategoriesStorage? {
        switch engine {
        case .swiftData:
            return try? SwiftDataCategoriesStorage()
        case .coreData:
            return try? CoreDataCategoriesStorage()
        }
    }

    private static func makeTransactions(_ engine: StorageEngine) -> TransactionsStorage? {
        switch engine {
        case .swiftData:
            return try? SwiftDataTransactionsStorage()
        case .coreData:
            return try? CoreDataTransactionsStorage()
        }
    }

    private static func makeAccounts(_ engine: StorageEngine) -> BankAccountsStorage? {
        switch engine {
        case .swiftData:
            return try? SwiftDataBankAccountsStorage()
        case .coreData:
            return try? CoreDataBankAccountsStorage()
        }
    }

    private static func makeTransactionsBackup(_ engine: StorageEngine) -> TransactionsBackupStorage? {
        switch engine {
        case .swiftData:
            return try? SwiftDataTransactionsBackupStorage()
        case .coreData:
            return try? CoreDataTransactionsBackupStorage()
        }
    }

    private static func makeAccountsBackup(_ engine: StorageEngine) -> BankAccountsBackupStorage? {
        switch engine {
        case .swiftData:
            return try? SwiftDataBankAccountsBackupStorage()
        case .coreData:
            return try? CoreDataBankAccountsBackupStorage()
        }
    }
}
