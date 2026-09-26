import SwiftUI

struct RankedMenuView: View {
    var result: OrderResult
    var createdAt: Date

    private let ink = HaveThisColor.ink

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink.opacity(0.65))
                Text("Protein, fiber, and saturated fat, each scored on its own. 0 is low, 2 is high.")
                    .font(.body)
                    .foregroundStyle(ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(result.dishes.enumerated()), id: \.offset) { index, dish in
                    dishBlock(rank: index + 1, dish: dish)
                }

                if !result.skipped.isEmpty {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ink.opacity(0.65))
                        .padding(.top, 8)
                    ForEach(Array(result.skipped.enumerated()), id: \.offset) { _, dish in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dish.name)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if let note = dish.skipNote {
                                Text(note)
                                    .font(.subheadline)
                                    .foregroundStyle(ink.opacity(0.65))
                            }
                            scores(for: dish)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .background(HaveThisColor.paper.ignoresSafeArea())
        .navigationTitle("Ranked")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dishBlock(rank: Int, dish: DishScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(rank)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ink.opacity(0.45))
                    .frame(width: 28, alignment: .leading)
                Text(dish.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            scores(for: dish)
                .padding(.leading, 40)
        }
    }

    private func scores(for dish: DishScore) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            scoreRow("Protein", dish.protein)
            scoreRow("Fiber", dish.fiber)
            scoreRow("Fat", dish.saturatedFat)
        }
    }

    private func scoreRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label)
                .frame(width: 72, alignment: .leading)
            Text(DishScore.band(value))
            Spacer(minLength: 8)
            Text(DishScore.number(value))
                .monospacedDigit()
        }
        .font(.subheadline)
        .foregroundStyle(ink.opacity(0.8))
    }
}

enum HaveThisColor {
    static let paper = Color(red: 0.965, green: 0.957, blue: 0.933)
    static let ink = Color(red: 0.180, green: 0.280, blue: 0.220)
}
