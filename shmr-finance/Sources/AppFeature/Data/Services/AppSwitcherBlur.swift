import UIKit

// Прячет содержимое приложения, когда оно уходит из активного состояния:
// в переключателе задач видны все открытые приложения, и суммы со счетами
// светиться там не должны.
//
// Размытие кладётся на окно, а не на экран: поверх окна лежат ещё и шторки —
// форма операции, фильтры, корректировка баланса. Экранный оверлей их бы
// не закрыл, а суммы есть и там.
@MainActor
final class AppSwitcherBlur: NSObject {

    static let shared = AppSwitcherBlur()

    private var blurView: UIVisualEffectView?
    private var isObserving = false

    func start() {
        guard isObserving == false else {
            return
        }
        isObserving = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hideContent),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(revealContent),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc
    private func hideContent() {
        guard blurView == nil, let window = keyWindow else {
            return
        }

        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        view.frame = window.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Без анимации: снимок для переключателя система делает сразу после
        // этого уведомления, и плавное появление она бы засняла наполовину.
        window.addSubview(view)
        blurView = view
    }

    @objc
    private func revealContent() {
        guard let view = blurView else {
            return
        }
        blurView = nil

        // А вот убирать можно плавно — пользователь уже смотрит на экран.
        UIView.animate(withDuration: 0.2) {
            view.alpha = 0
        } completion: { _ in
            view.removeFromSuperview()
        }
    }

    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { scene in
                scene as? UIWindowScene
            }
            .flatMap { scene in
                scene.windows
            }
            .first { window in
                window.isKeyWindow
            }
    }
}
