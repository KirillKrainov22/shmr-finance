import Foundation

// Универсальный сетевой клиент: собирает запрос, добавляет токен, кодирует тело и декодирует ответ. Про конкретные эндпоинты ничего не знает.
final class NetworkClient {

    static let shared = NetworkClient()

    private let baseURL = URL(string: "https://shmr-finance.ru/api/v1")!
    private let session = URLSession.shared

    // Запрос с телом (POST/PUT): тело кодируется в JSON, ответ декодируется.
    func request<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        method: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        let bodyData = try await encodeOnBackground(body)
        let data = try await perform(path: path, method: method, bodyData: bodyData)
        return try await decodeOnBackground(data)
    }

    // Запрос без тела (GET): только декодируем ответ.
    func request<ResponseBody: Decodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil
    ) async throws -> ResponseBody {
        let data = try await perform(path: path, method: method, queryItems: queryItems, bodyData: nil)
        return try await decodeOnBackground(data)
    }

    // Запрос без ответа (DELETE возвращает 204 без тела).
    func requestNoResponse(path: String, method: String) async throws {
        _ = try await perform(path: path, method: method, bodyData: nil)
    }

    // Собирает URLRequest, выполняет его и проверяет HTTP-код.
    private func perform(
        path: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        bodyData: Data?
    ) async throws -> Data {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(Secrets.apiToken)", forHTTPHeaderField: "Authorization")
        if bodyData != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = bodyData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.transportFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    // Кодирование на фоновом потоке (требование ТЗ): Task.detached уводит работу с основного потока, чтобы не подвешивать интерфейс.
    private func encodeOnBackground<Body: Encodable>(_ body: Body) async throws -> Data {
        let task = Task.detached(priority: .userInitiated) {
            do {
                return try JSONEncoder().encode(body)
            } catch {
                throw NetworkError.encodingFailed(error)
            }
        }
        return try await task.value
    }

    // Декодирование на фоновом потоке — по той же причине.
    private func decodeOnBackground<Body: Decodable>(_ data: Data) async throws -> Body {
        let task = Task.detached(priority: .userInitiated) {
            do {
                return try JSONDecoder().decode(Body.self, from: data)
            } catch {
                throw NetworkError.decodingFailed(error)
            }
        }
        return try await task.value
    }
}
