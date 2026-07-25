import Foundation

// Единственное место, где приложение решает, какой реализацией хранилища пользоваться.
// Когда появится вторая реализация на CoreData и переключатель в настройках,
// править нужно будет только здесь, а не в каждом сервисе.
enum LocalStorages {

    // nil, если базу не удалось открыть (нет места, битый файл).
    // Тогда приложение работает без кеша, но не падает.
    static let categories: CategoriesStorage? = try? SwiftDataCategoriesStorage()

    static let transactions: TransactionsStorage? = try? SwiftDataTransactionsStorage()

    static let accounts: BankAccountsStorage? = try? SwiftDataBankAccountsStorage()

    static let transactionsBackup: TransactionsBackupStorage? = try? SwiftDataTransactionsBackupStorage()

    static let accountsBackup: BankAccountsBackupStorage? = try? SwiftDataBankAccountsBackupStorage()
}
