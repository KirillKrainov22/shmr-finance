import Foundation

// Сервис категорий. Мок: данные захардкожены в коде.
final class CategoriesService {

    // Общий экземпляр на всё приложение.
    static let shared = CategoriesService()

    private let allCategories: [Category] = [
        Category(id: 1, name: "Зарплата", emoji: "💰", direction: .income),
        Category(id: 2, name: "Подработка", emoji: "💸", direction: .income),
        Category(id: 3, name: "Продукты", emoji: "🛒", direction: .outcome),
        Category(id: 4, name: "Кафе", emoji: "☕️", direction: .outcome),
        Category(id: 5, name: "Транспорт", emoji: "🚕", direction: .outcome),
        Category(id: 6, name: "Развлечения", emoji: "🎮", direction: .outcome)
    ]

    func categories() async -> [Category] {
        return allCategories
    }

    func categories(direction: Direction) async -> [Category] {
        return allCategories.filter { category in
            category.direction == direction
        }
    }
}

