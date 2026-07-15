import Foundation

// Хранит список операций и сохраняет/загружает его в json-файл.
// Разные кеши работают с разными файлами (задаётся именем файла).
final class TransactionsFileCache {

    private let fileName: String

    // private(set): читать снаружи можно, менять — только через методы класса.
    private(set) var transactions: [Transaction] = []

    init(fileName: String) {
        self.fileName = fileName
    }

    private var fileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents
            .appendingPathComponent(fileName)
            .appendingPathExtension("json")
    }

    // MARK: - Изменение коллекции

    func add(_ transaction: Transaction) {
        let alreadyExists = transactions.contains(where: { existing in
            existing.id == transaction.id
        })
        guard alreadyExists == false else { // защита от дублей по id
            return
        }
        transactions.append(transaction)
    }

    func remove(id: Int) {
        transactions.removeAll(where: { transaction in
            transaction.id == id
        })
    }

    // MARK: - Файл

    func save() throws {
        let jsonObjects = transactions.map { transaction in
            transaction.jsonObject
        }
        let data = try JSONSerialization.data(
            withJSONObject: jsonObjects,
            options: [.prettyPrinted]
        )
        try data.write(to: fileURL)
    }

    func load() throws {
        // Файла ещё нет — операций нет, это не ошибка.
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            transactions = []
            return
        }

        let data = try Data(contentsOf: fileURL)
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        guard let rawArray = jsonObject as? [Any] else {
            transactions = []
            return
        }

        // Битые элементы и дубликаты по id пропускаем.
        var loaded: [Transaction] = []
        for element in rawArray {
            guard let transaction = Transaction.parse(jsonObject: element) else {
                continue
            }
            let alreadyLoaded = loaded.contains(where: { existing in
                existing.id == transaction.id
            })
            guard alreadyLoaded == false else {
                continue
            }
            loaded.append(transaction)
        }

        transactions = loaded
    }
}
