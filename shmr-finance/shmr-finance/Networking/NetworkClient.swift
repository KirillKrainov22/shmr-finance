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

    // Выполняет запрос с повторами: временные сбои сервера не должны сразу превращаться в ошибку для пользователя.
    private func perform(
        path: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        bodyData: Data?
    ) async throws -> Data {
        // Запрос собираем один раз: тело уже закодировано, повторять нечего.
        let request = try makeRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            bodyData: bodyData
        )

        var retryIndex = 0
        while true {
            do {
                return try await send(request)
            } catch {
                retryIndex += 1
                // Повторяем только временные сбои и только ограниченное число раз.
                guard
                    RetryPolicy.shouldRetry(after: error),
                    retryIndex <= RetryPolicy.maxRetries
                else {
                    throw error
                }

                let delay = RetryPolicy.delay(forRetry: retryIndex)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    // Собирает URLRequest: адрес, метод, токен и тело.
    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem]?,
        bodyData: Data?
    ) throws -> URLRequest {
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

        return request
    }

    // Одна попытка: отправляет запрос и проверяет HTTP-код.
    private func send(_ request: URLRequest) async throws -> Data {
        // Связи нет — не занимаем время ожиданием таймаута. Ошибка та же,
        // что вернул бы URLSession, поэтому вся логика выше работает как прежде.
        guard NetworkMonitor.shared.isConnected else {
            throw NetworkError.transportFailed(URLError(.notConnectedToInternet))
        }

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

// Правила повторной отправки запроса при временных сбоях сервера.
private enum RetryPolicy {

    static let minDelay: Double = 2
    static let maxDelay: Double = 120
    static let factor: Double = 1.5
    static let jitter: Double = 0.05

    // Сколько раз повторяем запрос после первой неудачи. Ограничиваем, чтобы
    // пользователь не ждал минутами при недоступном сервере (5 попыток всего).
    static let maxRetries = 4

    // Коды, которые означают «сервер сейчас не может, попробуй позже»:
    // перегрузка, таймаут, лимит запросов. Остальные (например, 400 или 404) повторять бессмысленно — ответ не изменится.
    static let retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504]

    static func shouldRetry(after error: Error) -> Bool {
        guard case NetworkError.httpError(let statusCode) = error else {
            return false
        }
        return retryableStatusCodes.contains(statusCode)
    }

    // Пауза перед повтором №retryIndex (1 — перед первым повтором).
    // Растёт экспоненциально: 2с, 3с, 4.5с. MaxDelay — потолок формулы (пауза не становится длиннее двух минут), а не сигнал прекращать: число повторов ограничивает maxRetries.
    static func delay(forRetry retryIndex: Int) -> Double {
        let exponent = Double(retryIndex - 1)
        let base = min(minDelay * pow(factor, exponent), maxDelay)

        // Джиттер разводит во времени клиентов, которые начали повторять одновременно,
        // иначе они снова придут на сервер одной волной.
        let spread = Double.random(in: -jitter...jitter)
        return base * (1 + spread)
    }
}

