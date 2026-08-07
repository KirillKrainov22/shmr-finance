import Foundation

// Статья операции
struct Category: Identifiable, Hashable {
    let id: Int
    let name: String
    let emoji: Character // категории отображаются через эмодзи
    let direction: Direction

    init(id: Int, name: String, emoji: Character, direction: Direction) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.direction = direction
    }
}
