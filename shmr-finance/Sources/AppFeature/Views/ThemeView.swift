import SwiftUI

// Шторка выбора оформления: три варианта с галочкой у текущего.
struct ThemeView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = ThemeSettings.shared

    var body: some View {
        NavigationStack {
            List(AppTheme.allCases) { theme in
                Button {
                    settings.theme = theme
                } label: {
                    HStack {
                        Text(theme.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if settings.theme == theme {
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
            .navigationTitle("Тема оформления")
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
    ThemeView()
}
