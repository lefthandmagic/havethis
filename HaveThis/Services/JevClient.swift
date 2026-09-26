import Foundation

struct JevClient {
    var session: URLSession = .shared
    var apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "JevAPIKey") as? String

    func keepDishes(_ lines: [String]) async throws -> [String] {
        let capped = Array(lines.prefix(40))
        guard !capped.isEmpty else { return [] }

        var questions: [String: Any] = [:]
        for (index, line) in capped.enumerated() {
            questions["dish_\(index)"] = [
                "type": "noul",
                "instructions": [
                    "line": line,
                    "question": "Is `line` a specific dish or drink a customer can order? Yes for food and drinks. No for section titles, prices, addresses, hours, allergen legends, and the restaurant name."
                ],
                "criteria": [
                    "true": "A specific orderable dish or drink",
                    "false": "Not something to order"
                ]
            ]
        }

        let answers = try await evaluate(state: ["lines": capped], questions: questions)
        return capped.enumerated().compactMap { index, line in
            let yes = answers["dish_\(index)"]?.noul ?? 0
            return yes >= 0.6 ? line : nil
        }
    }

    func scoreDishes(_ names: [String]) async throws -> [DishScore] {
        let capped = Array(names.prefix(20))
        guard !capped.isEmpty else { return [] }

        var questions: [String: Any] = [:]
        for (index, name) in capped.enumerated() {
            questions["\(index)_protein"] = scoreQuestion(
                name,
                "How much protein is \(name) likely to have? Judge from the dish name only."
            )
            questions["\(index)_fiber"] = scoreQuestion(
                name,
                "How much fiber is \(name) likely to have? Judge from the dish name only."
            )
            questions["\(index)_sat"] = scoreQuestion(
                name,
                "How much saturated fat is \(name) likely to have? Cheese, cream, fried food, and red meat are high. Judge from the dish name only."
            )
            questions["\(index)_mollusk"] = flagQuestion(name, "mollusks such as oysters, mussels, clams, squid, or octopus")
            questions["\(index)_mushroom"] = flagQuestion(name, "mushrooms")
        }

        let answers = try await evaluate(state: ["dishes": capped], questions: questions)
        return capped.enumerated().compactMap { index, name in
            guard
                let protein = answers["\(index)_protein"]?.score,
                let fiber = answers["\(index)_fiber"]?.score,
                let sat = answers["\(index)_sat"]?.score
            else { return nil }
            return DishScore(
                name: name,
                protein: protein,
                fiber: fiber,
                saturatedFat: sat,
                mollusk: answers["\(index)_mollusk"]?.noul ?? 0,
                mushroom: answers["\(index)_mushroom"]?.noul ?? 0
            )
        }
    }

    private func scoreQuestion(_ name: String, _ question: String) -> [String: Any] {
        [
            "type": "score",
            "instructions": [
                "dish": name,
                "question": question
            ],
            "criteria": ["Low", "Moderate", "High"]
        ]
    }

    private func flagQuestion(_ name: String, _ ingredient: String) -> [String: Any] {
        [
            "type": "noul",
            "instructions": [
                "dish": name,
                "question": "Does the dish `dish` contain or likely contain \(ingredient)?"
            ],
            "criteria": [
                "true": "The dish includes it",
                "false": "The dish does not include it"
            ]
        ]
    }

    private func evaluate(state: Any, questions: [String: Any]) async throws -> [String: JevAnswer] {
        let key = (apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains("$(") else { throw OrderError.missingKey }

        let body: [String: Any] = [
            "model": "jev-latest",
            "state": state,
            "questions": questions
        ]
        let payload = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: URL(string: "https://thejevai.com/v1/systemone")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload
        request.timeoutInterval = 45

        let data = try await send(request, allowRetry: true)
        return try parse(data)
    }

    private func send(_ request: URLRequest, allowRetry: Bool) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw OrderError.scoringFailed }
            if (http.statusCode == 429 || http.statusCode == 529), allowRetry {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                return try await send(request, allowRetry: false)
            }
            guard (200..<300).contains(http.statusCode) else { throw OrderError.scoringFailed }
            return data
        } catch let error as OrderError {
            throw error
        } catch {
            throw OrderError.scoringFailed
        }
    }

    private func parse(_ data: Data) throws -> [String: JevAnswer] {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw OrderError.scoringFailed }

        let answers = (json["answers"] as? [String: Any])
            ?? ((json["result"] as? [String: Any])?["answers"] as? [String: Any])
        guard let answers else { throw OrderError.scoringFailed }

        var parsed: [String: JevAnswer] = [:]
        for (key, value) in answers {
            guard let object = value as? [String: Any] else { continue }
            parsed[key] = JevAnswer(
                noul: double(object["noul"]),
                score: double(object["score"])
            )
        }
        return parsed
    }
}

struct JevAnswer {
    var noul: Double?
    var score: Double?
}

private func double(_ value: Any?) -> Double? {
    if let number = value as? NSNumber { return number.doubleValue }
    return nil
}
