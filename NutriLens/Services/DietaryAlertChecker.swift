import Foundation

enum DietaryAlertChecker {
    struct Alert: Identifiable {
        let id = UUID()
        let restriction: DietaryRestriction
        let flaggedItem: String
        let reason: String
    }

    /// Check food items and AI dietary flags against user's restrictions
    static func check(
        items: [EditableFoodItem],
        flags: [String],
        restrictions: [DietaryRestriction]
    ) -> [Alert] {
        guard !restrictions.isEmpty else { return [] }

        var alerts: [Alert] = []

        // Check AI-provided dietary flags against restrictions
        for flag in flags {
            let flagLower = flag.lowercased()
            for restriction in restrictions {
                if flagMatches(flagLower, restriction: restriction) {
                    alerts.append(Alert(
                        restriction: restriction,
                        flaggedItem: flag,
                        reason: "AI detected: \(flag)"
                    ))
                }
            }
        }

        // Check food item names with keyword matching
        for item in items {
            let nameLower = item.name.lowercased()
            for restriction in restrictions {
                if let reason = keywordCheck(nameLower, restriction: restriction) {
                    // Avoid duplicate alerts
                    let isDuplicate = alerts.contains { $0.restriction == restriction && $0.flaggedItem == item.name }
                    if !isDuplicate {
                        alerts.append(Alert(
                            restriction: restriction,
                            flaggedItem: item.name,
                            reason: reason
                        ))
                    }
                }
            }
        }

        return alerts
    }

    // MARK: - Private

    private static func flagMatches(_ flag: String, restriction: DietaryRestriction) -> Bool {
        switch restriction {
        case .vegetarian:
            return flag.contains("not vegetarian") || flag.contains("contains meat")
        case .vegan:
            return flag.contains("not vegan") || flag.contains("contains dairy") ||
                   flag.contains("contains eggs") || flag.contains("contains meat")
        case .glutenFree:
            return flag.contains("contains gluten")
        case .dairyFree:
            return flag.contains("contains dairy")
        case .nutFree:
            return flag.contains("contains nuts") || flag.contains("contains peanut") || flag.contains("contains tree nut")
        case .shellfishFree:
            return flag.contains("contains shellfish")
        case .eggFree:
            return flag.contains("contains eggs") || flag.contains("contains egg")
        case .soyFree:
            return flag.contains("contains soy")
        case .lowSodium:
            return flag.contains("high sodium")
        case .halal:
            return flag.contains("not halal") || flag.contains("contains pork") || flag.contains("contains alcohol")
        case .kosher:
            return flag.contains("not kosher") || flag.contains("contains pork") || flag.contains("contains shellfish")
        }
    }

    private static func keywordCheck(_ name: String, restriction: DietaryRestriction) -> String? {
        switch restriction {
        case .vegetarian:
            let meats = ["chicken", "beef", "pork", "steak", "bacon", "sausage", "ham", "turkey", "fish", "salmon", "tuna", "shrimp", "lamb"]
            if let match = meats.first(where: { name.contains($0) }) {
                return "'\(match)' is not vegetarian"
            }
        case .vegan:
            let animal = ["chicken", "beef", "pork", "steak", "bacon", "fish", "salmon", "shrimp", "milk", "cheese", "butter", "cream", "egg", "honey", "yogurt", "whey"]
            if let match = animal.first(where: { name.contains($0) }) {
                return "'\(match)' is not vegan"
            }
        case .glutenFree:
            let gluten = ["bread", "pasta", "wheat", "flour", "noodle", "crouton", "tortilla", "pancake", "waffle", "cereal", "barley", "rye"]
            if let match = gluten.first(where: { name.contains($0) }) {
                return "'\(match)' may contain gluten"
            }
        case .dairyFree:
            let dairy = ["milk", "cheese", "butter", "cream", "yogurt", "ice cream", "whey", "casein"]
            if let match = dairy.first(where: { name.contains($0) }) {
                return "'\(match)' contains dairy"
            }
        case .nutFree:
            let nuts = ["almond", "cashew", "walnut", "pecan", "pistachio", "peanut", "hazelnut", "macadamia"]
            if let match = nuts.first(where: { name.contains($0) }) {
                return "'\(match)' contains nuts"
            }
        case .shellfishFree:
            let shellfish = ["shrimp", "crab", "lobster", "oyster", "clam", "mussel", "scallop", "crawfish"]
            if let match = shellfish.first(where: { name.contains($0) }) {
                return "'\(match)' is shellfish"
            }
        case .eggFree:
            let eggs = ["egg", "omelet", "omelette", "frittata", "meringue", "mayonnaise"]
            if let match = eggs.first(where: { name.contains($0) }) {
                return "'\(match)' contains egg"
            }
        case .soyFree:
            let soy = ["soy", "tofu", "tempeh", "edamame", "miso"]
            if let match = soy.first(where: { name.contains($0) }) {
                return "'\(match)' contains soy"
            }
        case .lowSodium:
            return nil // Hard to detect from name alone; rely on AI flags
        case .halal:
            let haram = ["pork", "bacon", "ham", "prosciutto", "pepperoni", "salami", "wine", "beer"]
            if let match = haram.first(where: { name.contains($0) }) {
                return "'\(match)' may not be halal"
            }
        case .kosher:
            let nonKosher = ["pork", "bacon", "ham", "shrimp", "lobster", "crab", "oyster"]
            if let match = nonKosher.first(where: { name.contains($0) }) {
                return "'\(match)' is not kosher"
            }
        }
        return nil
    }
}
