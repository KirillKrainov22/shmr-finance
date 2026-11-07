import SwiftUI

struct PasscodeView: View {
    let entered: Binding<String>
    let isTyping: FocusState<Bool>.Binding
    let length: Int
    let promptText: String
    let errorMessage: String?
    let shakeCount: Int
    let onFocus: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(errorMessage ?? promptText)
                .scaledFont(size: 15)
                .foregroundStyle(errorMessage == nil ? .secondary : Color.red)

            dots

            hiddenField

            Spacer()
        }
        .padding(.top, 32)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        // Клавиатуру можно смахнуть, а другого способа ввести код нет —
        // тап по экрану возвращает её.
        .contentShape(Rectangle())
        .onTapGesture {
            onFocus()
        }
    }

    // Поле нужно только чтобы поднять системную клавиатуру: видимая часть
    // ввода — точки выше. Полностью прозрачное поле система фокусировать
    // отказывается, поэтому оставляем еле заметную непрозрачность.
    private var hiddenField: some View {
        TextField("", text: entered)
            .keyboardType(.numberPad)
            .focused(isTyping)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityHidden(true)
    }

    private var dots: some View {
        HStack(spacing: 20) {
            ForEach(0..<length, id: \.self) { index in
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
                    .background(
                        Circle().fill(index < entered.wrappedValue.count ? Color.accentColor : .clear)
                    )
                    .frame(width: 14, height: 14)
            }
        }
        .modifier(ShakeEffect(shakes: shakeCount))
        .animation(.default, value: shakeCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: appString("Введено цифр: %lld из %lld"), entered.wrappedValue.count, length))
    }
}

// Покачивание точек при ошибке — привычный для iOS способ сказать
// «не то», не отнимая места под текст.
private struct ShakeEffect: GeometryEffect {

    var shakes: Int

    var animatableData: CGFloat {
        get {
            CGFloat(shakes)
        }
        set {
            shakes = Int(newValue)
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = 8 * sin(CGFloat(shakes) * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}
