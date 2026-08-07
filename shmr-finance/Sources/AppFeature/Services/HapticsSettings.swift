import Foundation
import Observation

// Включена ли тактильная отдача в приложении. Отдельно от системной настройки
// телефона: там глобальный выключатель на всё устройство, здесь — только на нас.
// Значение переживает перезапуск, поэтому лежит в UserDefaults.
@Observable
@MainActor
final class HapticsSettings {

    static let shared = HapticsSettings()

    private let key = "haptics_enabled"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: key)
        }
    }

    private init() {
        // По умолчанию включено. Проверяем именно наличие ключа: для
        // отсутствующего UserDefaults возвращает false, и отдача молча
        // оказалась бы выключенной у всех, кто её не трогал.
        if UserDefaults.standard.object(forKey: key) == nil {
            isEnabled = true
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: key)
        }
    }
}
