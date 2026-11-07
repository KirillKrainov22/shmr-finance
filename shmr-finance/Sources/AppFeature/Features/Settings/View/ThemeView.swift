import SwiftUI

struct ThemeView: View {
    let selected: AppTheme
    let onSelect: (AppTheme) -> Void

    var body: some View {
        List(AppTheme.allCases) { theme in
            Button {
                onSelect(theme)
            } label: {
                HStack {
                    Text(theme.title)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selected == theme {
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
    }
}
