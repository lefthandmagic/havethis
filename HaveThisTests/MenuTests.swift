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
        let result = OrderRanking.pick(from: [heavy, oysters, light])
        XCTAssertEqual(result?.pick.name, "Salmon")
        XCTAssertEqual(result?.alternatives.map(\.name), ["Cheese fries"])
        XCTAssertTrue(result?.reason.contains("protein") == true)
    }

    func testBlocksMollusksAndMushrooms() {
        let only = DishScore(name: "Mushroom ragout", protein: 1, fiber: 1.4, saturatedFat: 0.5, mollusk: 0, mushroom: 0.8)
        XCTAssertNil(OrderRanking.pick(from: [only]))
    }
}
