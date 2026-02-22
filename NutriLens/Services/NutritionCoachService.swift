import Foundation

struct CoachInsight {
    let message: String
    let emoji: String
    let tip: String
    let fetchedAt: Date
}

private struct CoachResponse: Codable {
    let message: String
    let emoji: String
    let tip: String
}

@Observable
final class NutritionCoachService {
    var latestInsight: CoachInsight?
    var isLoading = false
    var error: String?

    private let coachURL = URL(string: "\(AppConstants.apiBaseURL)/api/coach")!
    private var lastProgressHash: Int = 0

    /// Check if insight should be refreshed (stale after 30 min or progress changed significantly)
    func shouldRefresh(currentHash: Int) -> Bool {
        if latestInsight == nil { return true }
        if let fetchedAt = latestInsight?.fetchedAt,
           Date().timeIntervalSince(fetchedAt) > 1800 { return true }
        if currentHash != lastProgressHash { return true }
        return false
    }

    func fetchInsight(
        todayTotals: NutrientInfo,
        goal: DailyGoal?,
        streak: Int,
        restrictions: [DietaryRestriction]
    ) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 0..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        default: timeOfDay = "evening"
        }

        let restrictionString = restrictions.map(\.displayName).joined(separator: ", ")

        let progress: [String: Any] = [
            "calories": todayTotals.calories,
            "calorieTarget": goal?.calorieTarget ?? 2000,
            "protein": todayTotals.proteinGrams,
            "proteinTarget": goal?.proteinGramsTarget ?? 150,
            "carbs": todayTotals.carbsGrams,
            "carbsTarget": goal?.carbsGramsTarget ?? 250,
            "fat": todayTotals.fatGrams,
            "fatTarget": goal?.fatGramsTarget ?? 65
        ]

        let body: [String: Any] = [
            "progress": progress,
            "streak": streak,
            "timeOfDay": timeOfDay,
            "restrictions": restrictionString
        ]

        var request = URLRequest(url: coachURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConstants.appToken, forHTTPHeaderField: "X-App-Token")
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                error = "Failed to get coach response"
                return
            }

            // Parse Anthropic response envelope
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstBlock = content.first,
                  let text = firstBlock["text"] as? String else {
                error = "Unexpected response format"
                return
            }

            // Clean up markdown fences
            let cleaned = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let jsonData = cleaned.data(using: .utf8),
                  let coachResponse = try? JSONDecoder().decode(CoachResponse.self, from: jsonData) else {
                error = "Failed to parse coach response"
                return
            }

            latestInsight = CoachInsight(
                message: coachResponse.message,
                emoji: coachResponse.emoji,
                tip: coachResponse.tip,
                fetchedAt: Date()
            )

            // Save progress hash for staleness detection
            lastProgressHash = progressHash(totals: todayTotals)

        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Generate a simple hash of progress for change detection
    func progressHash(totals: NutrientInfo) -> Int {
        // Round to nearest 50 kcal / 10g to avoid constant re-fetching
        let calBucket = Int(totals.calories / 50)
        let proBucket = Int(totals.proteinGrams / 10)
        let carbBucket = Int(totals.carbsGrams / 10)
        let fatBucket = Int(totals.fatGrams / 10)
        return calBucket ^ (proBucket << 8) ^ (carbBucket << 16) ^ (fatBucket << 24)
    }
}
