import SwiftUI

// Шторка выбора оформления: три варианта с галочкой у текущего.
struct ThemeContainer: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: ThemeSettings

    var body: some View {
        NavigationStack {
            ThemeView(selected: settings.theme) { selected in
                settings.theme = selected
            }
            .navigationTitle(appString("Тема оформления"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
            }
            .hapticFeedback(.selection, trigger: settings.theme)
        }
        // Иначе iOS 26 рисует шторку стеклом, а в приложении все остальные белые.
        .presentationBackground(Color(.systemBackground))
    }
}

#Preview {
    ThemeContainer(settings: .shared)
}
