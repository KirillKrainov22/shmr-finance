import Foundation

// Перевод дат между Date и строками бэкенда.
enum APIDate {

    // Бэкенд может присылать даты и с долями секунды, и без — пробуем оба варианта.
    private static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // Формат "yyyy-MM-dd" для query-параметров периода.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        if let date = withFractional.date(from: string) {
            return date
        }
        return plain.date(from: string)
    }

    static func string(from date: Date) -> String {
        return withFractional.string(from: date)
    }

    static func dayString(from date: Date) -> String {
        return dayFormatter.string(from: date)
    }
}
