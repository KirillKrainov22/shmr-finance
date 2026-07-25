import Foundation
import SwiftData

// Локальное хранилище категорий. Категории не редактируются в приложении,
// поэтому хватает двух операций: отдать всё и заменить всё целиком.
protocol CategoriesStorage: Sendable {
    func getAll() async throws -> [Category]
    func replaceAll(with categories: [Category]) async throws
    // Нужен при смене движка хранения: старую базу после переноса чистим.
    func clear() async throws
}

// Строка таблицы категорий. Отдельный тип от доменной Category — по той же причине,
// по которой существуют DTO: модель приложения не должна знать про формат хранения.
@Model
final class CategoryEntity {

    @Attribute(.unique) var id: Int
    var name: String
    var emoji: String
    var isIncome: Bool

    init(category: Category) {
        id = category.id
        name = category.name
        emoji = String(category.emoji)
        isIncome = category.direction.isIncome
    }

    func toDomain() -> Category? {
        guard let emojiCharacter = emoji.first else {
            return nil
        }
        return Category(
            id: id,
            name: name,
            emoji: emojiCharacter,
            direction: Direction(isIncome: isIncome)
        )
    }
}

// @ModelActor дописывает контейнер, контекст и инициализатор с готовым контейнером.
// Актор нужен, чтобы к базе не обращались из двух мест одновременно.
@ModelActor
actor SwiftDataCategoriesStorage: CategoriesStorage {

    // Свой файл базы: у контейнеров по умолчанию один и тот же файл,
    // и три хранилища с разными схемами передрались бы за него.
    init() throws {
        let url = URL.documentsDirectory.appending(path: "Categories.store")
        let configuration = ModelConfiguration(url: url)
        let container = try ModelContainer(for: CategoryEntity.self, configurations: configuration)
        self.init(modelContainer: container)
    }

    func getAll() throws -> [Category] {
        let entities = try modelContext.fetch(FetchDescriptor<CategoryEntity>())
        return entities.compactMap { entity in
            entity.toDomain()
        }
    }

    func replaceAll(with categories: [Category]) throws {
        try modelContext.delete(model: CategoryEntity.self)
        for category in categories {
            modelContext.insert(CategoryEntity(category: category))
        }
        try modelContext.save()
    }

    func clear() throws {
        try modelContext.delete(model: CategoryEntity.self)
        try modelContext.save()
    }
}
