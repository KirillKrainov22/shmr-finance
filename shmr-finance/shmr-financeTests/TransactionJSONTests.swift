import Testing
import Foundation
@testable import shmr_finance

struct TransactionJSONTests {

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // Дата из строки без долей секунды — чтобы round-trip был точным.
    private func makeTransaction(comment: String? = "Комментарий") -> Transaction {
        let date = Self.dateFormatter.date(from: "2025-06-12T09:41:00Z")!
        return Transaction(
            id: 1,
            accountId: 2,
            categoryId: 3,
            amount: Decimal(500),
            transactionDate: date,
            comment: comment,
            createdAt: date,
            updatedAt: date
        )
    }

    // MARK: - jsonObject

    @Test func jsonObjectContainsAllFields() {
        let dictionary = makeTransaction().jsonObject as! [String: Any]

        #expect(dictionary["id"] as? Int == 1)
        #expect(dictionary["accountId"] as? Int == 2)
        #expect(dictionary["categoryId"] as? Int == 3)
        #expect(dictionary["amount"] as? String == "500")
        #expect(dictionary["comment"] as? String == "Комментарий")
    }

    @Test func jsonObjectOmitsNilComment() {
        let dictionary = makeTransaction(comment: nil).jsonObject as! [String: Any]

        #expect(dictionary["comment"] == nil)
    }

    // MARK: - parse

    @Test func parseRestoresTransaction() {
        let original = makeTransaction()

        let parsed = Transaction.parse(jsonObject: original.jsonObject)

        #expect(parsed == original)
    }

    @Test func parseWithoutComment() {
        let original = makeTransaction(comment: nil)

        let parsed = Transaction.parse(jsonObject: original.jsonObject)

        #expect(parsed == original)
        #expect(parsed?.comment == nil)
    }

    @Test func parseReturnsNilForNonDictionary() {
        #expect(Transaction.parse(jsonObject: "не словарь") == nil)
        #expect(Transaction.parse(jsonObject: [1, 2, 3]) == nil)
    }

    @Test func parseReturnsNilWhenFieldMissing() {
        var dictionary = makeTransaction().jsonObject as! [String: Any]
        dictionary["amount"] = nil

        #expect(Transaction.parse(jsonObject: dictionary) == nil)
    }

    @Test func parseReturnsNilForWrongType() {
        var dictionary = makeTransaction().jsonObject as! [String: Any]
        dictionary["id"] = "не число"

        #expect(Transaction.parse(jsonObject: dictionary) == nil)
    }
}
