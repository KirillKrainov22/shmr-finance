import SwiftUI

// Экран выбора статьи (категории). Поиск — нативный, на iOS 26 минимизируется в иконку.
struct CategoriesView: View {

    @State private var viewModel: CategoriesViewModel
    @Environment(\.dismiss) private var dismiss

    // Необязательный колбэк выбора: если задан — по тапу на статью она возвращается и экран закрывается.
    private let onSelect: ((Category) -> Void)?

    init(direction: Direction?, onSelect: ((Category) -> Void)? = nil) {
        _viewModel = State(initialValue: CategoriesViewModel(direction: direction))
        self.onSelect = onSelect
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        return NavigationStack {
            List(viewModel.filteredCategories) { category in
                row(for: category)
                    .frame(maxWidth: .infinity, alignment: .leading) // ячейка на всю ширину
                    .contentShape(Rectangle()) // тапабельна вся строка, а не только эмодзи с текстом
                    .onTapGesture {
                        onSelect?(category)
                        if onSelect != nil {
                            dismiss()
                        }
                    }
            }
            .listStyle(.plain)
            .navigationTitle(appString("Статьи"))
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, LocalizationSettings.shared.locale)
            .searchable(text: $viewModel.searchText, prompt: appString("Поиск"))
            .minimizedSearchBehavior()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarCloseButton {
                        dismiss()
                    }
                }
                // iOS 26: нативный поиск в нижнем баре, прижат вправо, минимизируется в иконку.
                if #available(iOS 26, *) {
                    ToolbarSpacer(.flexible, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .alert(appString("Ошибка"), isPresented: $viewModel.showError) {
                Button(appString("Ок"), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .errorFeedback(when: viewModel.showError)
            .task {
                await viewModel.load()
            }
        }
        // Лист открывается на средней высоте, при клавиатуре сам поднимается до .large.
        .presentationDetents([.medium, .large])
        .presentationBackground(Color(.systemBackground)) // белый фон, как у Настроек
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

extension View {
    // На iOS 26 минимизирует строку поиска в иконку; на более старых — без изменений.
    @ViewBuilder
    func minimizedSearchBehavior() -> some View {
        if #available(iOS 26, *) {
            self.searchToolbarBehavior(.minimize)
        } else {
            self
        }
    }
}

