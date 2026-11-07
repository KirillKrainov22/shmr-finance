import Foundation
import Observation

// Мозг экрана статей: грузит категории (с учётом направления) и фильтрует по поиску.
@Observable
final class CategoriesViewModel {

    // Направление: .outcome — расходные, .income — доходные, nil — все.
    let direction: Direction?
    var searchText = ""
    var categories: [Category] = []

    // Состояние загрузки и ошибки для экрана.
    var isLoading = false
    var showError = false
    var errorMessage = ""

    private let useCase: any CategoriesUseCase

    init(direction: Direction?, useCase: any CategoriesUseCase) {
        self.useCase = useCase
        self.direction = direction
    }

    // Категории, отфильтрованные нечётким поиском (fuzzy).
    var filteredCategories: [Category] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            return categories
        }
        return categories.filter { category in
            Self.fuzzyMatch(query: query, in: category.name)
        }
    }

    // Нечёткий поиск: символы запроса встречаются в названии по порядку,
    // но не обязательно подряд («прдкт» → «Продукты»).
    private static func fuzzyMatch(query: String, in text: String) -> Bool {
        let queryCharacters = Array(query.lowercased())
        let textCharacters = Array(text.lowercased())
        var matchedCount = 0

        for character in textCharacters {
            if matchedCount < queryCharacters.count && character == queryCharacters[matchedCount] {
                matchedCount += 1
            }
        }

        return matchedCount == queryCharacters.count
    }

    func load() async {
        isLoading = true
        defer {
            isLoading = false
        }

        do {
            categories = try await useCase.load(direction: direction)
        } catch {
            guard isCancellationError(error) == false else {
                return
            }
            errorMessage = userErrorMessage(from: error)
            showError = true
        }
    }
}
