import Foundation

struct JevClient {
    var session: URLSession = .shared
    var apiKey: String? = Bundle.main.object(forInfoDictionaryKey: "JevAPIKey") as? String

    func keepDishes(
        _ lines: [String],
        progress: (@Sendable (JevProgress) -> Void)? = nil
    ) async throws -> (dishes: [String], stats: JevCallStats) {
        let capped = Array(lines.prefix(40))
        guard !capped.isEmpty else { return ([], JevCallStats()) }

        var questions: [String: Any] = [:]
        for (index, line) in capped.enumerated() {
            questions["dish_\(index)"] = [
                "type": "noul",
                "instructions": "Is \"\(line)\" a specific dish or drink a customer can order? Yes for food and drinks. No for section titles, prices, addresses, hours, allergen legends, and the restaurant name.",
                "yes": "A specific orderable dish or drink",
                "no": "Not something to order"
            ]
        }

        let (answers, stats) = try await evaluate(
            state: ["lines": capped],
            questions: questions,
            label: "Finding dishes",
            progress: progress
        )
        return (
            capped.enumerated().compactMap { index, line in
                let yes = answers["dish_\(index)"]?.noul ?? 0
                return yes >= 0.6 ? line : nil
            },
            stats
        )
    }

    func scoreDishes(
        _ names: [String],
        progress: (@Sendable (JevProgress) -> Void)? = nil
    ) async throws -> (scores: [DishScore], stats: JevCallStats) {
        let capped = Array(names.prefix(20))
        guard !capped.isEmpty else { return ([], JevCallStats()) }

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

        let (answers, stats) = try await evaluate(
            state: ["dishes": capped],
            questions: questions,
            label: "Scoring dishes",
            progress: progress
        )
        return (
            capped.enumerated().compactMap { index, name in
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
        },
            stats
        )
    }

    private func scoreQuestion(_ name: String, _ question: String) -> [String: Any] {
        [
            "type": "score",
            "instructions": question,
            "criteria": ["Low", "Moderate", "High"]
        ]
    }

    private func flagQuestion(_ name: String, _ ingredient: String) -> [String: Any] {
        [
            "type": "noul",
            "instructions": "Does \(name) contain or likely contain \(ingredient)?",
            "yes": "The dish includes it",
            "no": "The dish does not include it"
        ]
    }

    /// Their playground sends this id. `jev-latest` is rejected by the same host.
    private static let model = "typesafe/jev-1.13"
    /// The playground refuses more than 8 questions in one call.
    private static let batchSize = 8

    private func evaluate(
        state: Any,
        questions: [String: Any],
        label: String,
        progress: (@Sendable (JevProgress) -> Void)?
    ) async throws -> (answers: [String: JevAnswer], stats: JevCallStats) {
        let ids = Array(questions.keys)
        let batches = max(1, Int(ceil(Double(ids.count) / Double(Self.batchSize))))
        var merged: [String: JevAnswer] = [:]
        var stats = JevCallStats()
        var start = 0
        var batchIndex = 0
        while start < ids.count {
            let end = min(start + Self.batchSize, ids.count)
            var batch: [String: Any] = [:]
            for id in ids[start..<end] {
                batch[id] = questions[id]
            }
            batchIndex += 1
            let callStarted = Date()
            progress?(JevProgress(
                title: label,
                detail: "Call \(batchIndex) of \(batches)",
                completedRoundTrip: stats.roundTrip,
                completedServer: stats.server,
                callStarted: callStarted
            ))
            let (part, server) = try await evaluateBatch(state: state, questions: batch)
            stats.roundTrip += Date().timeIntervalSince(callStarted)
            stats.server += server
            stats.calls += 1
            for (id, answer) in part {
                merged[id] = answer
            }
            progress?(JevProgress(
                title: label,
                detail: "Call \(batchIndex) of \(batches)",
                completedRoundTrip: stats.roundTrip,
                completedServer: stats.server,
                callStarted: nil
            ))
            start = end
        }
        return (merged, stats)
    }

    private func evaluateBatch(state: Any, questions: [String: Any]) async throws -> (answers: [String: JevAnswer], server: TimeInterval) {
        let key = (apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains("$(") else { throw OrderError.missingKey }

        let body: [String: Any] = [
            "model": Self.model,
            "state": state,
            "questions": questions
        ]
        let payload = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: URL(string: "https://thejevai.com/v1/systemone")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("HaveThis/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = payload
        request.timeoutInterval = 45

        let data = try await send(request, allowRetry: true)
        return (try parse(data), Self.serverSeconds(in: data))
    }

    private func send(_ request: URLRequest, allowRetry: Bool) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw OrderError.scoringFailed }
            if (http.statusCode == 429 || http.statusCode == 529), allowRetry {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                return try await send(request, allowRetry: false)
            }
            if !(200..<300).contains(http.statusCode) {
                throw OrderError.provider(Self.serverMessage(in: data) ?? OrderError.scoringFailed.localizedDescription)
            }
            if let message = Self.failureMessage(in: data) {
                throw OrderError.provider(message)
            }
            return data
        } catch let error as OrderError {
            throw error
        } catch {
            throw OrderError.scoringFailed
        }
    }

    private static func serverMessage(in data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = json["message"] as? String
        else { return nil }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func failureMessage(in data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let code = json["code"] as? NSNumber,
            code.intValue != 0
        else { return nil }
        return serverMessage(in: data) ?? OrderError.scoringFailed.localizedDescription
    }

    private func parse(_ data: Data) throws -> [String: JevAnswer] {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw OrderError.scoringFailed }

        let wrapped = (json["data"] as? [String: Any])?["result"] as? [String: Any]
        let answers = (json["answers"] as? [String: Any])
            ?? ((json["result"] as? [String: Any])?["answers"] as? [String: Any])
            ?? (wrapped?["answers"] as? [String: Any])
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

    /// Jev reports its own processing time as `elapsedMs` on the result.
    private static func serverSeconds(in data: Data) -> TimeInterval {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return 0 }
        let result = ((json["data"] as? [String: Any])?["result"] as? [String: Any])
            ?? (json["result"] as? [String: Any])
        guard let ms = result?["elapsedMs"] as? NSNumber else { return 0 }
        return ms.doubleValue / 1000
    }
}

struct JevCallStats: Sendable {
    var roundTrip: TimeInterval = 0
    var server: TimeInterval = 0
    var calls: Int = 0

    static func + (lhs: JevCallStats, rhs: JevCallStats) -> JevCallStats {
        JevCallStats(
            roundTrip: lhs.roundTrip + rhs.roundTrip,
            server: lhs.server + rhs.server,
            calls: lhs.calls + rhs.calls
        )
    }
}

struct JevProgress: Sendable {
    var title: String
    var detail: String
    var completedRoundTrip: TimeInterval
    var completedServer: TimeInterval
    var callStarted: Date?
}

struct JevAnswer {
    var noul: Double?
    var score: Double?
}

private func double(_ value: Any?) -> Double? {
    if let number = value as? NSNumber { return number.doubleValue }
    return nil
}
