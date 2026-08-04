import CoreData
import Foundation

// Общий каркас для хранилищ на CoreData.
//
// Модель описана кодом, а не нарисована в .xcdatamodeld: тогда она живёт
// в репозитории обычным Swift-файлом и её видно на ревью целиком.
//
// @unchecked Sendable: контекст сам по себе не потокобезопасен, но снаружи
// к нему обращаются только через context.perform, а он выполняет работу
// на собственной очереди — по одному вызову за раз, как актор у SwiftData.
final class CoreDataStack: @unchecked Sendable {

    let context: NSManagedObjectContext

    private let container: NSPersistentContainer

    init(name: String, entity: NSEntityDescription) throws {
        let model = NSManagedObjectModel()
        model.entities = [entity]

        container = NSPersistentContainer(name: name, managedObjectModel: model)

        // Свой файл на каждое хранилище — ровно как у SwiftData-версий.
        let url = URL.documentsDirectory.appending(path: "\(name).sqlite")
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url)]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }

        context = container.newBackgroundContext()
        // Уникальность по id решается на уровне базы: при конфликте побеждает
        // то, что мы записываем.
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }
}

// Хелперы описания модели — иначе каждое поле занимает четыре строки.
enum CoreDataModel {

    static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }

    static func entity(
        name: String,
        managedObjectClass: AnyClass,
        attributes: [NSAttributeDescription],
        uniqueBy: String
    ) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(managedObjectClass)
        entity.properties = attributes
        entity.uniquenessConstraints = [[uniqueBy]]
        return entity
    }
}

extension NSManagedObjectContext {

    // Достать все объекты сущности.
    func fetchAll<Object: NSManagedObject>(_ type: Object.Type, entityName: String) throws -> [Object] {
        let request = NSFetchRequest<Object>(entityName: entityName)
        return try fetch(request)
    }

    // Найти один объект по целочисленному id.
    func fetchOne<Object: NSManagedObject>(
        _ type: Object.Type,
        entityName: String,
        id: Int
    ) throws -> Object? {
        let request = NSFetchRequest<Object>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %d", id)
        request.fetchLimit = 1
        return try fetch(request).first
    }

    // Создать новый объект. Явно по имени сущности, а не через init(context:):
    // модель у нас собрана кодом, и поиск сущности по классу на ней подводит.
    func insert<Object: NSManagedObject>(_ type: Object.Type, entityName: String) -> Object? {
        NSEntityDescription.insertNewObject(forEntityName: entityName, into: self) as? Object
    }

    // Удалить всё содержимое сущности.
    func deleteAll(entityName: String) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        for object in try fetch(request) {
            delete(object)
        }
    }
}
