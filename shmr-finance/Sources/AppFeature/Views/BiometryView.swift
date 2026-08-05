import SwiftUI

// Шторка «Биометрия»: единственный переключатель со сноской о том,
// где хранятся данные.
struct BiometryView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable private var biometry = BiometrySettings.shared

    var body: some View {
        NavigationStack {
            List {
                Toggle(isOn: $biometry.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Face ID / Touch ID")
                        Text(subtitle)
                            .scaledFont(size: 13)
                            .foregroundStyle(.secondary)
                    }
                }
                // Без код-пароля включать нечего: биометрия только заменяет
                // его ввод, а подтвердить вход иначе будет нечем.
                .disabled(biometry.canBeEnabled == false)
            }
            .listStyle(.plain)
            .background(Color(.systemBackground))
            .navigationTitle("Биометрия")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
            }
            .hapticFeedback(.selection, trigger: biometry.isEnabled)
        }
        // Иначе iOS 26 рисует шторку стеклом, а в приложении все остальные белые.
        .presentationBackground(Color(.systemBackground))
    }

    // Пока включить нельзя — объясняем почему, а не оставляем серую строку молча.
    private var subtitle: String {
        if biometry.isAvailable == false {
            return "Недоступна на этом устройстве"
        }
        if PasscodeStore.isSet == false {
            return "Сначала установите ПИН-код"
        }
        return "Хранятся только на вашем устройстве"
    }
}

#Preview {
    BiometryView()
}
