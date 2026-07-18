import Foundation
import Observation

// Мозг экрана статей: грузит категории (с учётом направления) и фильтрует по поиску.
@Observable
final class CategoriesViewModel {

    // Направление: .outcome — расходные, .income — доходные, nil — все.
    let direction: Direction?
    var searchText = ""
    var categories: [Category] = []

    private let service = CategoriesService()

    init(direction: Direction?) {
        self.direction = direction
    }

    // Категории, отфильтрованные по строке поиска.
    var filteredCategories: [Category] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            return categories
        }
        return categories.filter { category in
            category.name.range(of: query, options: .caseInsensitive) != nil
        }
    }

    func load() async {
        if let direction {
            categories = await service.categories(direction: direction)
        } else {
            categories = await service.categories()
        }
    }
}
