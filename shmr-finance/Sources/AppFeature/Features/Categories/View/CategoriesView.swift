import SwiftUI

struct CategoriesView: View {
    let categories: [Category]
    let onSelect: ((Category) -> Void)?

    var body: some View {
        List(categories) { category in
            row(for: category)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onSelect?(category) }
        }
        .listStyle(.plain)
    }

    private func row(for category: Category) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.separator), lineWidth: 1)
                    .scaledSquare(40)
                Text(String(category.emoji))
                    .scaledFont(size: 22)
            }
            // Эмодзи — украшение, его название только зашумит озвучку.
            .accessibilityHidden(true)
            Text(category.name)
                .scaledFont(size: 16, weight: .medium)
        }
        .accessibilityElement(children: .combine)
    }
}
