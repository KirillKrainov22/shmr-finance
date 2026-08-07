import Foundation
import Observation

// Какой счёт пользователь выбрал основным. Раньше такого понятия не было,
// и каждый экран брал accounts.first сам по себе — отсюда расхождение
// между списком из сети и списком из кеша.

@Observable
@MainActor
final class SelectedAccountStore {

    static let shared = SelectedAccountStore()

    private let key = "selected_account_id"

    private(set) var id: Int?

    private init() {
        // UserDefaults не отличает отсутствие ключа от нуля,
        // поэтому ноль читаем как «выбор ещё не сделан».
        let stored = UserDefaults.standard.integer(forKey: key)
        if stored == 0 {
            id = nil
        } else {
            id = stored
        }
    }

    func select(id newID: Int) {
        guard newID != id else {
            return
        }
        id = newID
        UserDefaults.standard.set(newID, forKey: key)
    }
}
