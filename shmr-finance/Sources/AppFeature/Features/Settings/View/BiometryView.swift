import SwiftUI

struct BiometryView: View {
    let isEnabled: Binding<Bool>
    let canBeEnabled: Bool
    let subtitle: String

    var body: some View {
        List {
            Toggle(isOn: isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Face ID / Touch ID")
                    Text(subtitle)
                        .scaledFont(size: 13)
                        .foregroundStyle(.secondary)
                }
            }
            // Без код-пароля включать нечего: биометрия только заменяет
            // его ввод, а подтвердить вход иначе будет нечем.
            .disabled(!canBeEnabled)
        }
        .listStyle(.plain)
        .background(Color(.systemBackground))
    }
}
