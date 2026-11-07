import SwiftUI
import Observation
import PieChart

// Язык интерфейса. Переводов ровно два, как просит ТЗ, поэтому и вариантов
// в настройках два — без пункта «системный»: иначе при системном языке
// галочка не стояла бы ни на одной строке списка.
enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"

    var id: Self {
        self
    }

    // Название языка пишем на нём самом — так его узнает и тот, кто открыл
    // приложение с незнакомым языком.
    var title: String {
        switch self {
        case .russian:
            return appString("Русский")
        case .english:
            return "English"
        }
    }
}

@Observable
@MainActor
final class LocalizationSettings {

    static let shared = LocalizationSettings()

    private let key = "app_language"

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: key)
            PieChartLocalization.use(language: language.rawValue)
        }
    }

    // Для SwiftUI: экраны берут отсюда и локализацию строк, и формат дат
    // с суммами, поэтому язык меняется без перезапуска приложения.
    var locale: Locale {
        Locale(identifier: language.rawValue)
    }

    // Для UIKit-экрана аналитики: окружения SwiftUI там нет, и нужный перевод
    // приходится доставать из бандла с этим языком вручную.
    var bundle: Bundle {
        guard
            let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .main
        }
        return bundle
    }

    private init() {
        if let stored = UserDefaults.standard.string(forKey: key),
           let saved = AppLanguage(rawValue: stored) {
            language = saved
            return
        }
        // Первый запуск: подстраиваемся под телефон. Английский — для всех,
        // у кого система на нём, остальным русский.
        let preferred = Locale.preferredLanguages.first ?? "ru"
        language = preferred.hasPrefix("en") ? .english : .russian
    }

    // Диаграмму нужно предупредить и на старте, а не только при смене языка:
    // didSet при первом чтении настроек не срабатывает.
    func start() {
        PieChartLocalization.use(language: language.rawValue)
    }
}

// Короткая запись для UIKit-экранов: там строки берутся не из окружения,
// а из бандла выбранного языка.
func appString(_ key: String) -> String {
    LocalizationSettings.shared.bundle.localizedString(forKey: key, value: nil, table: nil)
}
