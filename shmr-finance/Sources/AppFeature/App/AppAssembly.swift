import SwiftUI

@MainActor
struct AppAssembly {
    func makeTransactionsList(direction: Direction) -> some View {
        let useCase = TransactionsListUseCaseImpl(
            transactionsService: .shared,
            categoriesService: .shared,
            selectedAccount: .shared
        )
        return TransactionsListAssembly(useCase: useCase, localization: .shared).makeView(direction: direction)
    }

    func makeTransactionEdit(
        mode: TransactionFormMode,
        direction: Direction,
        onFinish: @escaping () -> Void
    ) -> some View {
        let useCase = TransactionFormUseCaseImpl(
            transactionsService: .shared,
            accountsService: .shared,
            categoriesService: .shared
        )
        return TransactionFormAssembly(useCase: useCase).makeView(mode: mode, direction: direction, onFinish: onFinish)
    }

    func makeCategories(direction: Direction?, onSelect: ((Category) -> Void)? = nil) -> some View {
        let useCase = CategoriesUseCaseImpl(service: .shared)
        return CategoriesAssembly(useCase: useCase).makeView(direction: direction, onSelect: onSelect)
    }

    func makeAccounts(isVisible: Bool) -> some View {
        let useCase = AccountsUseCaseImpl(
            service: .shared,
            transactionsService: .shared,
            categoriesService: .shared,
            selection: .shared
        )
        return AccountsAssembly(useCase: useCase).makeView(isVisible: isVisible)
    }

    func makeAccountEdit(onFinish: @escaping () -> Void) -> some View {
        let useCase = AccountFormUseCaseImpl(service: .shared)
        return AccountFormAssembly(useCase: useCase).makeView(onFinish: onFinish)
    }

    func makeAnalytics(direction: Direction?) -> AnalyticsViewController {
        let useCase = AnalyticsUseCaseImpl(
            transactionsService: .shared,
            categoriesService: .shared,
            accountsService: .shared
        )
        return AnalyticsAssembly(useCase: useCase, localization: .shared, haptics: .shared).makeController(direction: direction)
    }

    var passcode: PasscodeAssembly {
        PasscodeAssembly(useCase: PasscodeUseCaseImpl(biometry: .shared), haptics: .shared)
    }

    func makeSettings(direction: Direction?) -> some View {
        SettingsAssembly(haptics: .shared, theme: .shared, localization: .shared, biometry: .shared, passcode: passcode)
            .makeView(direction: direction)
    }
}
