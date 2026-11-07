import CoreHaptics
import Foundation

// Проигрывание ahap-узора через Core Haptics.
final class SplashHaptics {

    private var engine: CHHapticEngine?

    func play() {
        guard HapticsSettings.shared.isEnabled else {
            return
        }
        // На iPad и iPhone до восьмого вибромотора нужного типа нет —
        // молча выходим, иначе движок бросит ошибку на ровном месте.
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }
        guard let url = Bundle.main.url(forResource: "splash_haptics", withExtension: "ahap") else {
            return
        }

        do {
            let engine = try CHHapticEngine()
            self.engine = engine
            try engine.start()
            try engine.playPattern(from: url)
        } catch {
            // Вибрация — украшение. Если движок не завёлся, запуск приложения
            // из-за этого ломаться не должен.
            engine = nil
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
    }
}
