import SwiftUI
import UIKit
import Observation

// Оформление приложения. «Системная» означает следовать настройке телефона,
// поэтому у неё нет своей схемы — только отсутствие принуждения.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .system:
            return "Системная"
        case .light:
            return "Светлая"
        case .dark:
            return "Тёмная"
        }
    }

    // Для SwiftUI: nil — не навязывать, пусть решает система.
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    // Для UIKit-экрана аналитики: preferredColorScheme туда не доходит.
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system:
            return .unspecified
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@Observable
@MainActor
final class ThemeSettings {

    static let shared = ThemeSettings()

    private let key = "app_theme"

    var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: key)
            apply()
        }
    }

    // Стиль ставим окну целиком, а не через preferredColorScheme. Тот задаёт
    // схему своему поддереву, а шторка показывается отдельно и получает тему
    // только в момент открытия: сменил тему при открытой — она не изменится
    // до закрытия. Окно накрывает и шторки, и UIKit-экран аналитики.
    func apply() {
        let style = theme.interfaceStyle
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else {
                continue
            }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: key) ?? ""
        theme = AppTheme(rawValue: stored) ?? .system
    }
}
