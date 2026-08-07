import Foundation

// Пакет не знает, какой язык выбран в приложении: настройки живут снаружи,
// а зависимость в эту сторону только одна — приложение → пакет. Поэтому язык
// сообщают диаграмме, а она достаёт из своего бандла нужный перевод.
public enum PieChartLocalization {

    private nonisolated(unsafe) static var bundle: Bundle = .module

    public static func use(language code: String) {
        guard
            let path = Bundle.module.path(forResource: code, ofType: "lproj"),
            let localized = Bundle(path: path)
        else {
            bundle = .module
            return
        }
        bundle = localized
    }

    static func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
