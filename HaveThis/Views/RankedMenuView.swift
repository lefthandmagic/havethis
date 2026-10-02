import SwiftUI

struct RankedMenuView: View {
    var result: OrderResult
    var createdAt: Date
    var timing: ScanTiming? = nil
    var preferences: DietPreferences = .open
    var busy: String? = nil
    var onAddPhoto: () -> Void = {}

    private let ink = HaveThisColor.ink

    private var ranked: OrderResult {
        var ordered = OrderRanking.rank(
            from: result.dishes + result.skipped,
            preferences: preferences
        )
        ordered.unscored = result.unscored
        return ordered
    }

    var body: some View {
        let shown = ranked
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink.opacity(0.65))
                #if DEBUG
                if let timing {
                    Text(timing.line)
                        .font(.subheadline)
                        .foregroundStyle(ink.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                #endif
                Text("Estimated from the dish name, not a lab value.")
                    .font(.body)
                    .foregroundStyle(ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                if let busy {
                    Text(busy)
                        .font(.headline)
                        .foregroundStyle(ink)
                }

                if shown.unscored > 0 {
                    Text(unscoredLine(shown.unscored))
                        .font(.body)
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let pick = shown.dishes.first {
                    featured(pick, kicker: "Have this")
                }

                let backups = Array(shown.dishes.dropFirst().prefix(2))
                if !backups.isEmpty {
                    Text("Also")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ink.opacity(0.65))
                        .padding(.top, 8)
                    ForEach(Array(backups.enumerated()), id: \.offset) { _, dish in
                        featured(dish, kicker: nil)
                    }
                }

                let rest = Array(shown.dishes.dropFirst(3))
                if !rest.isEmpty {
                    Text("Rest of the menu")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ink.opacity(0.65))
                        .padding(.top, 8)
                    ForEach(Array(rest.enumerated()), id: \.offset) { _, dish in
                        restRow(dish)
                    }
                }

                if !shown.skipped.isEmpty {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ink.opacity(0.65))
                        .padding(.top, 8)
                    ForEach(Array(shown.skipped.enumerated()), id: \.offset) { _, dish in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dish.name)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if let note = skipNote(for: dish) {
                                Text(note)
                                    .font(.subheadline)
                                    .foregroundStyle(ink.opacity(0.65))
                            }
                            Text("\(dish.scoreLabel) / 10")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(ink.opacity(0.75))
                            factorLabels(dish)
                        }
                    }
                }

                Button(action: onAddPhoto) {
                    Text("Add another photo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.bordered)
                .tint(ink)
                .disabled(busy != nil)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .background(HaveThisColor.paper.ignoresSafeArea())
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func unscoredLine(_ count: Int) -> String {
        let noun = count == 1 ? "dish" : "dishes"
        return "\(count) \(noun) on this photo weren't scored. Add a photo of that part of the menu."
    }

    private func skipNote(for dish: DishScore) -> String? {
        let mollusk = preferences.skipMollusks && dish.mollusk >= 0.55
        let mushroom = preferences.skipMushrooms && dish.mushroom >= 0.55
        switch (mollusk, mushroom) {
        case (true, true): return "Mollusk and mushroom"
        case (true, false): return "Mollusk"
        case (false, true): return "Mushroom"
        case (false, false): return nil
        }
    }

    private func featured(_ dish: DishScore, kicker: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let kicker {
                Text(kicker)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink.opacity(0.65))
            }
            Text(dish.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(dish.scoreLabel) / 10")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(ink)
            Text(dish.reason)
                .font(.body)
                .foregroundStyle(ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            factorLabels(dish)
        }
    }

    private func restRow(_ dish: DishScore) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(dish.name)
                .foregroundStyle(ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Text(dish.scoreLabel)
                .monospacedDigit()
                .foregroundStyle(ink.opacity(0.55))
        }
        .font(.subheadline)
    }

    private func factorLabels(_ dish: DishScore) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            factorRow("Protein", dish.protein)
            factorRow("Fiber", dish.fiber)
            factorRow("Saturated fat", dish.saturatedFat)
        }
    }

    private func factorRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 8)
            Text(DishScore.band(value))
        }
        .font(.subheadline)
        .foregroundStyle(ink.opacity(0.8))
    }
}

enum HaveThisColor {
    static let paper = Color(red: 0.965, green: 0.957, blue: 0.933)
    static let ink = Color(red: 0.180, green: 0.280, blue: 0.220)
}
