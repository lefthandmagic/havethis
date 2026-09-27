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
        let result = OrderRanking.rank(from: [heavy, oysters, light])
        XCTAssertEqual(result.dishes.map(\.name), ["Salmon", "Cheese fries"])
        XCTAssertEqual(result.skipped.map(\.name), ["Oysters"])
    }

    func testBlocksMollusksAndMushrooms() {
        let only = DishScore(name: "Mushroom ragout", protein: 1, fiber: 1.4, saturatedFat: 0.5, mollusk: 0, mushroom: 0.8)
        let result = OrderRanking.rank(from: [only])
        XCTAssertTrue(result.dishes.isEmpty)
        XCTAssertEqual(result.skipped.map(\.name), ["Mushroom ragout"])
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
}
