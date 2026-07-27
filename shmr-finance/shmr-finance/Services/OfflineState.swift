import Foundation
import Observation

// Общий признак «на экране данные из локального хранилища».
// Сервисы поднимают его, когда отвечают из кеша, и опускают при успешном ответе сервера.
// Флагом, а не возвращаемым значением: так сигнатуры сервисов остались прежними.
@Observable
@MainActor
final class OfflineState {

    static let shared = OfflineState()

    private(set) var isOffline = false

    private init() {}

    func markOffline() {
        isOffline = true
    }

    func markOnline() {
        isOffline = false
    }
}
