import Foundation

// Ошибки сетевого слоя. Разделены по природе:
// что именно сломалось — кодирование, сам запрос, код ответа или разбор ответа.
enum NetworkError: Error {
    case invalidURL
    case encodingFailed(Error)
    case transportFailed(Error)
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed(Error)
}

extension NetworkError {
    // Человеческий текст для алерта — без кодов и технических деталей.
    var userMessage: String {
        switch self {
        case .transportFailed:
            return "Нет соединения с сервером. Проверьте интернет."
        case .httpError:
            return "Сервер не смог обработать запрос. Попробуйте позже."
        case .encodingFailed, .decodingFailed:
            return "Не удалось обработать данные."
        case .invalidURL, .invalidResponse:
            return "Что-то пошло не так. Попробуйте ещё раз."
        }
    }
}

// Единая точка превращения любой ошибки в текст для пользователя.
func userErrorMessage(from error: Error) -> String {
    if let networkError = error as? NetworkError {
        return networkError.userMessage
    }
    return "Что-то пошло не так. Попробуйте ещё раз."
}

// Обрыв связи, а не отказ сервера. Откладывать в бэкап имеет смысл только такие ошибки:
// 400 или 404 повторной отправкой не исправить, они будут висеть в очереди вечно.
func isOfflineError(_ error: Error) -> Bool {
    guard isCancellationError(error) == false else {
        return false
    }
    guard case NetworkError.transportFailed = error else {
        return false
    }
    return true
}

// Отменённый запрос (например, SwiftUI сам отменил Task у .refreshable) — это не ошибка сети,
// пользователю её показывать не нужно.
func isCancellationError(_ error: Error) -> Bool {
    if error is CancellationError {
        return true
    }
    if case NetworkError.transportFailed(let underlying) = error {
        return (underlying as? URLError)?.code == .cancelled
    }
    return (error as? URLError)?.code == .cancelled
}
