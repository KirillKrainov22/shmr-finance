@MainActor
protocol PasscodeUseCase {
    var isSet: Bool { get }
    var length: Int { get }
    func authenticateIfEnabled() async -> Bool
    func matches(_ code: String) -> Bool
    func save(_ code: String)
}

struct PasscodeUseCaseImpl: PasscodeUseCase {
    let biometry: BiometrySettings

    var isSet: Bool { PasscodeStore.isSet }
    var length: Int { PasscodeStore.length }

    func authenticateIfEnabled() async -> Bool {
        guard biometry.shouldAsk else { return false }
        return await biometry.authenticate()
    }

    func matches(_ code: String) -> Bool {
        PasscodeStore.matches(code)
    }

    func save(_ code: String) {
        PasscodeStore.save(code)
    }
}
