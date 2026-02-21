import Foundation
import UIKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case pdf = "PDF"
    var id: String { rawValue }
}

enum ExportRange: String, CaseIterable, Identifiable {
    case week = "Last 7 Days"
    case month = "Last 30 Days"
    case allTime = "All Time"
    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .allTime: return nil
        }
    }
}

enum ExportService {

    // MARK: - Filter

    static func filteredMeals(_ meals: [Meal], range: ExportRange) -> [Meal] {
        guard let days = range.days else { return meals }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return meals.filter { $0.timestamp >= cutoff }
    }

    // MARK: - CSV

    static func generateCSV(meals: [Meal]) -> URL {
        let header = "Date,Time,Name,Meal Type,Calories,Protein (g),Carbs (g),Fat (g),Fiber (g),Sugar (g)\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        var csv = header
        for meal in meals.sorted(by: { $0.timestamp > $1.timestamp }) {
            let row = [
                dateFormatter.string(from: meal.timestamp),
                timeFormatter.string(from: meal.timestamp),
                escapedCSV(meal.name),
                meal.mealType.displayName,
                String(format: "%.0f", meal.totalCalories),
                String(format: "%.1f", meal.totalProteinGrams),
                String(format: "%.1f", meal.totalCarbsGrams),
                String(format: "%.1f", meal.totalFatGrams),
                String(format: "%.1f", meal.totalFiberGrams),
                String(format: "%.1f", meal.totalSugarGrams)
            ].joined(separator: ",")
            csv += row + "\n"
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MealSight_Export_\(dateStamp()).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - PDF

    static func generatePDF(meals: [Meal], goal: DailyGoal?) -> URL {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2

        let pdfURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MealSight_Export_\(dateStamp()).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let sortedMeals = meals.sorted { $0.timestamp > $1.timestamp }
        let summaries = buildDailySummaries(from: sortedMeals)

        let data = renderer.pdfData { context in
            context.beginPage()
            var y = margin

            // Title
            y = drawText("MealSight Nutrition Report", at: CGPoint(x: margin, y: y),
                         font: .boldSystemFont(ofSize: 22), maxWidth: contentWidth)
            y += 4

            // Date range
            let rangeText: String
            if let first = sortedMeals.last?.timestamp, let last = sortedMeals.first?.timestamp {
                let df = DateFormatter()
                df.dateStyle = .medium
                rangeText = "\(df.string(from: first)) – \(df.string(from: last))  •  \(sortedMeals.count) meals"
            } else {
                rangeText = "No meals"
            }
            y = drawText(rangeText, at: CGPoint(x: margin, y: y),
                         font: .systemFont(ofSize: 12), color: .secondaryLabel, maxWidth: contentWidth)
            y += 20

            // Daily summary table header
            let columns: [(String, CGFloat)] = [
                ("Date", 100), ("Meals", 50), ("Calories", 70),
                ("Protein", 70), ("Carbs", 70), ("Fat", 70)
            ]

            y = drawTableHeader(columns: columns, x: margin, y: y, context: context)

            for summary in summaries {
                if y > pageHeight - margin - 30 {
                    context.beginPage()
                    y = margin
                    y = drawTableHeader(columns: columns, x: margin, y: y, context: context)
                }

                let df = DateFormatter()
                df.dateStyle = .short
                let values = [
                    df.string(from: summary.date),
                    "\(summary.mealCount)",
                    String(format: "%.0f", summary.totalCalories),
                    String(format: "%.1fg", summary.totalProtein),
                    String(format: "%.1fg", summary.totalCarbs),
                    String(format: "%.1fg", summary.totalFat)
                ]

                y = drawTableRow(values: values, widths: columns.map { $0.1 }, x: margin, y: y)
            }

            // Goal section
            if let goal {
                y += 20
                if y > pageHeight - margin - 60 {
                    context.beginPage()
                    y = margin
                }
                y = drawText("Daily Goals", at: CGPoint(x: margin, y: y),
                             font: .boldSystemFont(ofSize: 16), maxWidth: contentWidth)
                y += 4
                let goalText = "Calories: \(String(format: "%.0f", goal.calorieTarget)) kcal  |  Protein: \(String(format: "%.0f", goal.proteinGramsTarget))g  |  Carbs: \(String(format: "%.0f", goal.carbsGramsTarget))g  |  Fat: \(String(format: "%.0f", goal.fatGramsTarget))g"
                y = drawText(goalText, at: CGPoint(x: margin, y: y),
                             font: .systemFont(ofSize: 11), color: .secondaryLabel, maxWidth: contentWidth)
            }
        }

        try? data.write(to: pdfURL)
        return pdfURL
    }

    // MARK: - Private Helpers

    private static func escapedCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }

    private static func dateStamp() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    private static func buildDailySummaries(from meals: [Meal]) -> [NutritionCalculator.DailySummary] {
        let grouped = Dictionary(grouping: meals) { meal in
            Calendar.current.startOfDay(for: meal.timestamp)
        }

        return grouped.map { date, dayMeals in
            NutritionCalculator.DailySummary(
                date: date,
                totalCalories: dayMeals.reduce(0) { $0 + $1.totalCalories },
                totalProtein: dayMeals.reduce(0) { $0 + $1.totalProteinGrams },
                totalCarbs: dayMeals.reduce(0) { $0 + $1.totalCarbsGrams },
                totalFat: dayMeals.reduce(0) { $0 + $1.totalFatGrams },
                mealCount: dayMeals.count
            )
        }.sorted { $0.date > $1.date }
    }

    // MARK: - PDF Drawing Helpers

    @discardableResult
    private static func drawText(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        color: UIColor = .label,
        maxWidth: CGFloat = 532
    ) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let rect = CGRect(x: point.x, y: point.y, width: maxWidth, height: .greatestFiniteMagnitude)
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        (text as NSString).draw(in: rect, withAttributes: attributes)
        return point.y + boundingRect.height
    }

    private static func drawTableHeader(
        columns: [(String, CGFloat)],
        x: CGFloat,
        y: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let headerFont = UIFont.boldSystemFont(ofSize: 10)
        var xPos = x
        for (title, width) in columns {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.label
            ]
            (title as NSString).draw(
                in: CGRect(x: xPos, y: y, width: width, height: 16),
                withAttributes: attributes
            )
            xPos += width
        }

        // Draw separator line
        let lineY = y + 18
        context.cgContext.setStrokeColor(UIColor.separator.cgColor)
        context.cgContext.setLineWidth(0.5)
        context.cgContext.move(to: CGPoint(x: x, y: lineY))
        context.cgContext.addLine(to: CGPoint(x: xPos, y: lineY))
        context.cgContext.strokePath()

        return lineY + 4
    }

    private static func drawTableRow(
        values: [String],
        widths: [CGFloat],
        x: CGFloat,
        y: CGFloat
    ) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 10)
        var xPos = x
        for (value, width) in zip(values, widths) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.label
            ]
            (value as NSString).draw(
                in: CGRect(x: xPos, y: y, width: width, height: 16),
                withAttributes: attributes
            )
            xPos += width
        }
        return y + 18
    }
}
