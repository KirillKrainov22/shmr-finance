import SwiftUI

// Шторка «Биометрия»: единственный переключатель со сноской о том,
// где хранятся данные.
struct BiometryContainer: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var biometry: BiometrySettings
    let passcode: any PasscodeUseCase

    var body: some View {
        NavigationStack {
            BiometryView(isEnabled: $biometry.isEnabled, canBeEnabled: biometry.canBeEnabled, subtitle: subtitle)
            .navigationTitle(appString("Биометрия"))
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
            return appString("Недоступна на этом устройстве")
        }
        if passcode.isSet == false {
            return appString("Сначала установите ПИН-код")
        }
        return appString("Хранятся только на вашем устройстве")
    }
}

#Preview {
    BiometryContainer(biometry: .shared, passcode: AppAssembly().passcode.useCase)
}
