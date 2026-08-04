import SwiftUI

extension View {
    // Liquid Glass на iOS 26, серая капсула как фолбэк на более старых версиях.
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self.background(Capsule().fill(Color(.systemGray6)))
        }
    }
}

// Крестик в панели. На iOS 26 у роли .close есть системный вид, и он же
// используется на экране аналитики — поэтому кнопки везде выглядят одинаково.
// На iOS 18 роли ещё нет, рисуем сами.
struct ToolbarCloseButton: View {

    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            Button(role: .close, action: action)
                .accessibilityLabel("Закрыть")
        } else {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(.systemGray5)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
        }
    }
}

// Галочка подтверждения: залитая акцентом кнопка с белым значком.
struct ToolbarConfirmButton: View {

    let label: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            // Значок задаём сами: у роли .confirm он берёт цвет от стиля кнопки
            // и получается не белым. Внутренний foregroundStyle перебивает это.
            Button(role: .confirm, action: action) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.white)
            }
            .tint(.accentColor)
            .accessibilityLabel(label)
        } else {
            Button(action: action) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        }
    }
}
