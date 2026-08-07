import SwiftUI
import CoreHaptics
import Lottie

// Заставка при запуске: проигрывает анимацию один раз и сообщает, когда
// закончила. Обёртка над UIKit-вьюхой Lottie — только у неё проигрывание
// с колбэком завершения, а по ТЗ интерфейс показывается строго после него.
struct SplashView: UIViewRepresentable {

    let name: String
    let onFinish: () -> Void

    // Узор вибрации живёт в координаторе: он переживает пересоздание
    // структуры и его есть кому остановить при закрытии заставки.
    func makeCoordinator() -> SplashHaptics {
        SplashHaptics()
    }

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: name)
        view.contentMode = .scaleAspectFit
        view.loopMode = .playOnce

        // Файла нет или он битый — не запирать пользователя на заставке.
        guard view.animation != nil else {
            DispatchQueue.main.async {
                onFinish()
            }
            return view
        }

        // Вибрация стартует вместе с анимацией — узор расписан под её длительность.
        context.coordinator.play()

        // Колбэк зовём в любом случае, даже если проигрывание оборвали:
        // иначе приложение зависнет на заставке навсегда.
        view.play { _ in
            onFinish()
        }
        return view
    }

    func updateUIView(_ view: LottieAnimationView, context: Context) {
    }

    static func dismantleUIView(_ view: LottieAnimationView, coordinator: SplashHaptics) {
        coordinator.stop()
    }
}

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
