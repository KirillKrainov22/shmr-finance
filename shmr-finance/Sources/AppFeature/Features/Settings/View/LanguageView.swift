import SwiftUI

struct LanguageView: View {
    let selected: AppLanguage
    let onSelect: (AppLanguage) -> Void

    var body: some View {
        List(AppLanguage.allCases) { language in
            Button {
                onSelect(language)
            } label: {
                HStack {
                    Text(language.title)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selected == language {
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
