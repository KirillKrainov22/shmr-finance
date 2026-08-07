import SwiftUI

// Шторка выбора языка: устроена как «Тема оформления» — список с галочкой
// у текущего варианта.
struct LanguageView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = LocalizationSettings.shared

    var body: some View {
        NavigationStack {
            List(AppLanguage.allCases) { language in
                Button {
                    settings.language = language
                } label: {
                    HStack {
                        Text(language.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if settings.language == language {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .background(Color(.systemBackground))
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
    LanguageView()
}
