import Foundation

// Категория, как её присылает бэкенд.
struct CategoryDTO: Decodable {
    let id: Int
    let name: String
    let emoji: String
    let isIncome: Bool

    // Перевод в доменную модель. nil, если данные битые (пустое эмодзи).
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
