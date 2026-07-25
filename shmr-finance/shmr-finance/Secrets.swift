import Foundation

enum Secrets {

    static let apiToken: String = {
        let token = Bundle.main.object(forInfoDictionaryKey: "APIToken") as? String

        guard
            let token,
            token.isEmpty == false,
            token != "PASTE_YOUR_TOKEN_HERE"
        else {
            // Без токена приложение не сделает ни одного запроса, так что падаем
            // сразу и с понятным текстом, а не ловим 401 на каждом экране.
            fatalError(
                "Не найден токен. Скопируй Config.example.xcconfig в Config.xcconfig и впиши свой."
            )
        }

        return token
    }()
}
