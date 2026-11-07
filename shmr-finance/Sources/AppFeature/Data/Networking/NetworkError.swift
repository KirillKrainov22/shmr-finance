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
            return appString("Нет соединения с сервером. Проверьте интернет.")
        case .httpError:
            return appString("Сервер не смог обработать запрос. Попробуйте позже.")
        case .encodingFailed, .decodingFailed:
            return appString("Не удалось обработать данные.")
        case .invalidURL, .invalidResponse:
            return appString("Что-то пошло не так. Попробуйте ещё раз.")
        }
    }
}

// Единая точка превращения любой ошибки в текст для пользователя.
func userErrorMessage(from error: Error) -> String {
    if let networkError = error as? NetworkError {
        return networkError.userMessage
    }
    return appString("Что-то пошло не так. Попробуйте ещё раз.")
}

// Сервер отказал по конфликту. Единственный случай в нашем API — попытка
// удалить счёт, по которому есть операции. Общий текст про «не смог обработать»
// тут бесполезен: пользователю нужно знать, что именно мешает.
func isConflictError(_ error: Error) -> Bool {
    guard case NetworkError.httpError(let statusCode) = error else {
        return false
    }
    return statusCode == 409
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
