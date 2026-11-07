@MainActor
protocol CategoriesUseCase {
    func load(direction: Direction?) async throws -> [Category]
}

struct CategoriesUseCaseImpl: CategoriesUseCase {
    let service: CategoriesService

    func load(direction: Direction?) async throws -> [Category] {
        if let direction {
            return try await service.categories(direction: direction)
        }
        return try await service.categories()
    }
}
