import CoreData
import Foundation

// Категория в базе CoreData. Аналог CategoryEntity из SwiftData-версии.
final class CDCategory: NSManagedObject {

    static let entityName = "CDCategory"

    @NSManaged var id: Int64
    @NSManaged var name: String
    @NSManaged var emoji: String
    @NSManaged var isIncome: Bool

    static func entityDescription() -> NSEntityDescription {
        CoreDataModel.entity(
            name: entityName,
            managedObjectClass: CDCategory.self,
            attributes: [
                CoreDataModel.attribute("id", .integer64AttributeType),
                CoreDataModel.attribute("name", .stringAttributeType),
                CoreDataModel.attribute("emoji", .stringAttributeType),
                CoreDataModel.attribute("isIncome", .booleanAttributeType)
            ],
            uniqueBy: "id"
        )
    }

    func apply(_ category: Category) {
        id = Int64(category.id)
        name = category.name
        emoji = String(category.emoji)
        isIncome = category.direction.isIncome
    }

    func toDomain() -> Category? {
        guard let emojiCharacter = emoji.first else {
            return nil
        }
        return Category(
            id: Int(id),
            name: name,
            emoji: emojiCharacter,
            direction: Direction(isIncome: isIncome)
        )
    }
}

final class CoreDataCategoriesStorage: CategoriesStorage, @unchecked Sendable {

    private let stack: CoreDataStack

    init() throws {
        stack = try CoreDataStack(name: "Categories", entity: CDCategory.entityDescription())
    }

    func getAll() async throws -> [Category] {
        let context = stack.context
        return try await context.perform {
            try context.fetchAll(CDCategory.self, entityName: CDCategory.entityName)
                .compactMap { entity in
                    entity.toDomain()
                }
        }
    }

    func replaceAll(with categories: [Category]) async throws {
        let context = stack.context
        try await context.perform {
            try context.deleteAll(entityName: CDCategory.entityName)
            for category in categories {
                let entity = context.insert(CDCategory.self, entityName: CDCategory.entityName)
                entity?.apply(category)
            }
            try context.save()
        }
    }

    func clear() async throws {
        let context = stack.context
        try await context.perform {
            try context.deleteAll(entityName: CDCategory.entityName)
            try context.save()
        }
    }
}
