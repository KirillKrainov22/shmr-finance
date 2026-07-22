import Foundation

// Сервис категорий: данные с бэкенда через NetworkClient.
final class CategoriesService {

    // Общий экземпляр на всё приложение.
    static let shared = CategoriesService()

    private let client = NetworkClient.shared

    func categories() async throws -> [Category] {
        let dtos: [CategoryDTO] = try await client.request(path: "categories")
        return dtos.compactMap { dto in
            dto.toDomain()
        }
    }

    func categories(direction: Direction) async throws -> [Category] {
        let dtos: [CategoryDTO] = try await client.request(
            path: "categories/type/\(direction.isIncome)"
        )
        return dtos.compactMap { dto in
            dto.toDomain()
        }
    }
}

