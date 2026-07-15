import Foundation

// Направление операции: доход или расход
enum Direction {
    case income
    case outcome

    // Бэкенд отдаёт направление булевым полем isIncome
    init(isIncome: Bool) {
        if isIncome {
            self = .income
        } else {
            self = .outcome
        }
    }

    var isIncome: Bool {
        switch self {
        case .income:
            return true
        case .outcome:
            return false
        }
    }
}
