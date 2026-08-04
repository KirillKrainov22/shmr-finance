import SwiftUI
import Lottie

// Заставка при запуске: проигрывает анимацию один раз и сообщает, когда
// закончила. Обёртка над UIKit-вьюхой Lottie — только у неё проигрывание
// с колбэком завершения, а по ТЗ интерфейс показывается строго после него.
struct SplashView: UIViewRepresentable {

    let name: String
    let onFinish: () -> Void

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

        // Колбэк зовём в любом случае, даже если проигрывание оборвали:
        // иначе приложение зависнет на заставке навсегда.
        view.play { _ in
            onFinish()
        }
        return view
    }

    func updateUIView(_ view: LottieAnimationView, context: Context) {
    }
}
