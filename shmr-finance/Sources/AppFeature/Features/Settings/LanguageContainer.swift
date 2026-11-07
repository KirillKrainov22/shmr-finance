import SwiftUI

// Шторка выбора языка: устроена как «Тема оформления» — список с галочкой
// у текущего варианта.
struct LanguageContainer: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: LocalizationSettings

    var body: some View {
        NavigationStack {
            LanguageView(selected: settings.language) { selected in
                settings.language = selected
            }
            .navigationTitle(appString("Язык"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
            }
            .hapticFeedback(.selection, trigger: settings.language)
        }
        // Иначе iOS 26 рисует шторку стеклом, а в приложении все остальные нет.
        .presentationBackground(Color(.systemBackground))
    }
}

#Preview {
    LanguageContainer(settings: .shared)
}
