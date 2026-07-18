import SwiftUI

// Экран выбора статьи (категории) с поиском по кнопке-лупе снизу.
struct CategoriesView: View {

    @State private var viewModel: CategoriesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSearching = false
    @FocusState private var searchFocused: Bool

    init(direction: Direction?) {
        _viewModel = State(initialValue: CategoriesViewModel(direction: direction))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            List(viewModel.filteredCategories) { category in
                row(for: category)
            }
            .listStyle(.plain)
            .navigationTitle("Статьи")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, Locale(identifier: "ru_RU"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        circleIcon("xmark")
                    }
                    .buttonStyle(.plain)
                }
            }
            // Кнопка-лупа справа снизу, пока не ищем.
            .overlay(alignment: .bottomTrailing) {
                if isSearching == false {
                    Button {
                        isSearching = true
                        searchFocused = true
                    } label: {
                        circleIcon("magnifyingglass", size: 56)
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                }
            }
            // Строка поиска снизу над клавиатурой.
            .safeAreaInset(edge: .bottom) {
                if isSearching {
                    HStack(spacing: 8) {
                        HStack {
                            TextField("Поиск", text: $viewModel.searchText)
                                .focused($searchFocused)
                            if viewModel.searchText.isEmpty == false {
                                Button {
                                    viewModel.searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .glassCapsule()

                        Button {
                            isSearching = false
                            viewModel.searchText = ""
                            searchFocused = false
                        } label: {
                            circleIcon("xmark")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.bar)
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private func row(for category: Category) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.separator), lineWidth: 1)
                    .frame(width: 40, height: 40)
                Text(String(category.emoji))
                    .font(.system(size: 22))
            }
            Text(category.name)
                .font(.system(size: 16, weight: .medium))
        }
    }

    private func circleIcon(_ systemName: String, size: CGFloat = 32) -> some View {
        Image(systemName: systemName)
            .font(.system(size: size == 56 ? 18 : 14, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .glassCapsule()
    }
}

#Preview {
    CategoriesView(direction: .outcome)
}

