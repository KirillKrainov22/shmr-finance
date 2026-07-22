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
