import Foundation

// Сервис категорий: данные с бэкенда через NetworkClient, копия — в локальном хранилище.
final class CategoriesService {

    // Общий экземпляр на всё приложение.
    static let shared = CategoriesService()

    private let client = NetworkClient.shared
    private let storage = LocalStorages.categories

    func categories() async throws -> [Category] {
        do {
            let dtos: [CategoryDTO] = try await client.request(path: "categories")
            let categories = dtos.compactMap { dto in
                dto.toDomain()
            }
            // Кеш обновляем при каждом успешном ответе. Сбой записи не должен
            // ронять запрос: данные у пользователя уже есть.
            try? await storage?.replaceAll(with: categories)
            return categories
        } catch {
            let cached = (try? await storage?.getAll()) ?? []
            guard cached.isEmpty == false else {
                throw error
            }
            return cached
        }
    }

    func categories(direction: Direction) async throws -> [Category] {
        do {
            let dtos: [CategoryDTO] = try await client.request(
                path: "categories/type/\(direction.isIncome)"
            )
            // В кеш этот ответ не пишем: здесь только половина категорий,
            // и replaceAll стёр бы вторую.
            return dtos.compactMap { dto in
                dto.toDomain()
            }
        } catch {
            let cached = (try? await storage?.getAll()) ?? []
            let filtered = cached.filter { category in
                category.direction == direction
            }
            guard filtered.isEmpty == false else {
                throw error
            }
            return filtered
        }
    }
}
