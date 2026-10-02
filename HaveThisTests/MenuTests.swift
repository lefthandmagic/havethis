import XCTest
@testable import HaveThis

final class MenuTests: XCTestCase {
    func testGroupsWordsOnTheSameLine() {
        let lines = MenuLayout.lines(from: [
            TextBlock(text: "Burrata", rect: CGRect(x: 0.1, y: 0.8, width: 0.3, height: 0.04)),
            TextBlock(text: "14.50", rect: CGRect(x: 0.7, y: 0.8, width: 0.15, height: 0.04)),
            TextBlock(text: "Salmon", rect: CGRect(x: 0.1, y: 0.6, width: 0.3, height: 0.04))
        ])
        XCTAssertEqual(lines, ["Burrata 14.50", "Salmon"])
    }

    func testDropsPricesHoursAndHeaders() {
        let kept = MenuLineFilter.candidates([
            "Burrata 14.50",
            "Grilled salmon, fennel 22,-",
            "Voorgerechten",
            "Maandag - vrijdag 12:00",
            "Keizersgracht 57",
            "€ 12,50",
            "Burrata"
        ])
        XCTAssertEqual(kept, ["Burrata", "Grilled salmon, fennel"])
    }

    func testDoesNotCollapseThePageIntoOneLine() {
        let blocks = (0..<5).map { index in
            TextBlock(
                text: "Dish \(index)",
                rect: CGRect(x: 0.1, y: 0.8 - CGFloat(index) * 0.08, width: 0.4, height: 0.03)
            )
        }
        XCTAssertEqual(MenuLayout.lines(from: blocks).count, 5)
    }

    func testKeepsNumberedAllCapsDishes() {
        let kept = MenuLineFilter.candidates([
            "VEG APPETIZERS",
            "111 65(PANEER/GOBI) € 10.00",
            "Deep-fried Paneer/cauliflower florets dipped in a spicy hot and tangy marinade",
            "MEDHU VADA Soft, crispy lentil doughnut shaped fritters € 7.00",
            "The Chettiars, also known as the Nagarathar community, have a history that dates back centuries. They are believed to have originated as traders and financiers, and their prominence grew during the medieval and colonial periods."
        ])
        XCTAssertEqual(kept, [
            "65(PANEER/GOBI)",
            "Deep-fried Paneer/cauliflower florets dipped in a spicy hot and tangy marinade",
            "MEDHU VADA"
        ])
    }

    func testRanksProteinAndFiberAboveAHeavyPlate() {
        let light = DishScore(name: "Salmon", protein: 2, fiber: 1.5, saturatedFat: 0.4, mollusk: 0.1, mushroom: 0)
        let heavy = DishScore(name: "Cheese fries", protein: 0.4, fiber: 0.2, saturatedFat: 1.8, mollusk: 0, mushroom: 0)
        let oysters = DishScore(name: "Oysters", protein: 1.6, fiber: 0.2, saturatedFat: 0.3, mollusk: 0.9, mushroom: 0)
        let skipping = DietPreferences(skipMollusks: true, skipMushrooms: false)
        let result = OrderRanking.rank(from: [heavy, oysters, light], preferences: skipping)
        XCTAssertEqual(result.dishes.map(\.name), ["Salmon", "Cheese fries"])
        XCTAssertEqual(result.skipped.map(\.name), ["Oysters"])
    }

    func testOpenPreferencesKeepMollusksInTheRanking() {
        let oysters = DishScore(name: "Oysters", protein: 1.6, fiber: 0.2, saturatedFat: 0.3, mollusk: 0.9, mushroom: 0)
        let result = OrderRanking.rank(from: [oysters])
        XCTAssertEqual(result.dishes.map(\.name), ["Oysters"])
        XCTAssertTrue(result.skipped.isEmpty)
    }

    func testBlocksMollusksAndMushrooms() {
        let only = DishScore(name: "Mushroom ragout", protein: 1, fiber: 1.4, saturatedFat: 0.5, mollusk: 0, mushroom: 0.8)
        let skipping = DietPreferences(skipMollusks: true, skipMushrooms: true)
        let result = OrderRanking.rank(from: [only], preferences: skipping)
        XCTAssertTrue(result.dishes.isEmpty)
        XCTAssertEqual(result.skipped.map(\.name), ["Mushroom ragout"])
    }

    func testScoreOutOfTenAndReasonUseTheThreeFactors() {
        let best = DishScore(name: "Salmon", protein: 2, fiber: 2, saturatedFat: 0, mollusk: 0, mushroom: 0)
        XCTAssertEqual(best.scoreLabel, "10.0")
        XCTAssertEqual(best.reason, "High protein, high fiber, lower saturated fat.")

        let mixed = DishScore(name: "Chicken", protein: 2, fiber: 1.2, saturatedFat: 1.8, mollusk: 0, mushroom: 0)
        XCTAssertEqual(mixed.scoreLabel, "5.7")
        XCTAssertEqual(mixed.reason, "High protein, moderate fiber, higher saturated fat.")

        let worst = DishScore(name: "Fries", protein: 0, fiber: 0, saturatedFat: 2, mollusk: 0, mushroom: 0)
        XCTAssertEqual(worst.scoreLabel, "0.0")
        XCTAssertEqual(worst.reason, "Low protein, low fiber, higher saturated fat.")
    }

    func testBandsAreIndependentOfEachOther() {
        XCTAssertEqual(DishScore.band(1.99), "High")
        XCTAssertEqual(DishScore.band(1.2), "Moderate")
        XCTAssertEqual(DishScore.band(0.4), "Low")
    }

    func testOldHistoryDecodesWithoutTiming() throws {
        let json = """
        [{"id":"00000000-0000-0000-0000-000000000001","createdAt":"2026-09-26T12:00:00Z","result":{"dishes":[],"skipped":[]}}]
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let searches = try decoder.decode([MenuSearch].self, from: json)
        XCTAssertNil(searches.first?.timing)
    }

    func testTimingLineSplitsPhotoAndJev() {
        let timing = ScanTiming(photoSeconds: 0.8, jevSeconds: 11.4, serverSeconds: 8.9)
        XCTAssertEqual(timing.line, "Photo 0.8s · Jev 11s (8.9s on their side)")
    }

    func testMergeAddsTheNewDishAndKeepsUnscored() {
        let salmon = DishScore(name: "Salmon", protein: 2, fiber: 1, saturatedFat: 0.4, mollusk: 0, mushroom: 0)
        let lamb = DishScore(name: "Lamb", protein: 2, fiber: 0.4, saturatedFat: 1, mollusk: 0, mushroom: 0)
        let base = OrderResult(dishes: [salmon], skipped: [], unscored: 2)
        let addition = OrderResult(
            dishes: [
                DishScore(name: "salmon", protein: 1, fiber: 1, saturatedFat: 0.4, mollusk: 0, mushroom: 0),
                lamb
            ],
            skipped: [],
            unscored: 1
        )
        let merged = MenuMerge.combining(base, with: addition)
        XCTAssertEqual(merged.dishes.map(\.name), ["Salmon", "Lamb"])
        XCTAssertEqual(merged.unscored, 3)
    }

    func testOldResultDecodesWithoutUnscored() throws {
        let json = #"{"dishes":[],"skipped":[]}"#.data(using: .utf8)!
        let result = try JSONDecoder().decode(OrderResult.self, from: json)
        XCTAssertEqual(result.unscored, 0)
    }

    func testAllowanceUsesPlusBeforeThePack() {
        let next = ScanAllowance.consume(plus: true, plusUsed: 0, packRemaining: 4)
        XCTAssertEqual(next?.plusUsed, 1)
        XCTAssertEqual(next?.packRemaining, 4)
    }

    func testAllowanceStopsWhenEmpty() {
        XCTAssertNil(ScanAllowance.consume(plus: false, plusUsed: 30, packRemaining: 0))
    }

    func testScansStayOpenUntilPurchasesExist() {
        XCTAssertTrue(ScanAllowance.canScan(purchasesAvailable: false, plus: false, plusUsed: 0, packRemaining: 0))
        XCTAssertFalse(ScanAllowance.canScan(purchasesAvailable: true, plus: false, plusUsed: 0, packRemaining: 0))
    }

    func testTimingLineCountsCalls() {
        let timing = ScanTiming(photoSeconds: 0.8, jevSeconds: 1.4, serverSeconds: 0.9, calls: 2)
        XCTAssertEqual(timing.line, "Photo 0.8s · Jev 1.4s (0.9s on their side) · 2 calls")
    }

}
