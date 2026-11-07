import Foundation
import Security

// Хранилище код-пароля. Keychain, а не UserDefaults: последний лежит
// обычным файлом в песочнице приложения, и пароль оттуда достаётся
// без всякого взлома.
enum PasscodeStore {

    // По ТЗ допускается только четырёхзначный код.
    static let length = 4

    private static let service = "ru.shmr.finance.passcode"
    private static let account = "user"
    private static let installMarkerKey = "passcode_install_marker"

    static var isSet: Bool {
        forgetCodeAfterReinstall()
        return read() != nil
    }

    // Keychain переживает удаление приложения, а UserDefaults — нет. Значит
    // отсутствие метки означает свежую установку, и код из прошлой жизни
    // приложения надо стереть: пользователь этой установки его не задавал.
    private static func forgetCodeAfterReinstall() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: installMarkerKey) == false else {
            return
        }
        remove()
        defaults.set(true, forKey: installMarkerKey)
    }

    static func save(_ code: String) {
        remove()

        guard let data = code.data(using: .utf8) else {
            return
        }

        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Рекомендация Apple для секретов, нужных только этому устройству:
            // читается лишь на разблокированном телефоне и не уезжает
            // на другой при восстановлении из резервной копии.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(item as CFDictionary, nil)
    }

    static func matches(_ code: String) -> Bool {
        guard let stored = read() else {
            return false
        }
        return stored == code
    }

    static func remove() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
