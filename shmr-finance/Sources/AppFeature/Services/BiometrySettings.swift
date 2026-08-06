import Foundation
import LocalAuthentication
import Observation

// Вход по биометрии. Это не замена код-паролю, а способ его не вводить:
// биометрия может не сработать (маска, мокрые руки, три неудачи подряд),
// и запасной путь через код должен оставаться всегда.
@Observable
@MainActor
final class BiometrySettings {

    static let shared = BiometrySettings()

    private let key = "biometry_enabled"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: key)
        }
    }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: key)
    }

    // Умеет ли устройство биометрию и настроена ли она у пользователя.
    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // Включать биометрию без код-пароля нельзя: при неудачном распознавании
    // человеку нечем будет подтвердить, что телефон его.
    var canBeEnabled: Bool {
        isAvailable && PasscodeStore.isSet
    }

    // Спрашивать биометрию есть смысл, только если она и включена, и доступна:
    // пользователь мог отключить Face ID в настройках телефона уже после того,
    // как включил его у нас.
    var shouldAsk: Bool {
        isEnabled && isAvailable && PasscodeStore.isSet
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        // Своя кнопка отказа: системная «Введите пароль» открыла бы пароль
        // устройства, а нам нужен наш ПИН-код.
        context.localizedFallbackTitle = ""

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: appString("Вход в приложение")
            )
        } catch {
            // Отказ, отмена или неудачное распознавание — не ошибка:
            // просто остаёмся на вводе ПИН-кода.
            return false
        }
    }
}
