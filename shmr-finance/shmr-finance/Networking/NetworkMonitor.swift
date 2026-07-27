import Foundation
import Network

// Следит за наличием сети средствами системы.
//
// Нужен ради скорости офлайна: без него каждый запрос уходит в URLSession
// и ждёт таймаута, а таких запросов на одну загрузку экрана набирается
// с полдюжины. Система же знает об отсутствии связи мгновенно.
//
// @unchecked Sendable: флаг читают и пишут из разных потоков,
// доступ к нему закрыт замком.
final class NetworkMonitor: @unchecked Sendable {

    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private let lock = NSLock()

    // true до первого ответа системы: лучше зря сходить в сеть,
    // чем ошибочно отказать в запросе на старте приложения.
    private var connected = true

    var isConnected: Bool {
        lock.lock()
        defer {
            lock.unlock()
        }
        return connected
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.update(connected: path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    private func update(connected value: Bool) {
        lock.lock()
        connected = value
        lock.unlock()
    }
}
