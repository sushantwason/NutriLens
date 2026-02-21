import UIKit
import Foundation

enum NutriLensError: LocalizedError {
    case imageProcessingFailed
    case networkError(Error)
    case apiError(statusCode: Int, message: String)
    case unexpectedResponse
    case jsonParsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process the image. Please try again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .unexpectedResponse:
            return "Received an unexpected response from the API."
        case .jsonParsingFailed(let detail):
            return "Failed to parse nutritional data: \(detail)"
        }
    }
}

@Observable
final class ClaudeVisionService {
    private let analyzeURL = URL(string: "\(AppConstants.apiBaseURL)/api/analyze")!

    func analyzeMealPhoto(_ image: UIImage) async throws -> MealAnalysisResponse {
        let responseText = try await sendAnalysisRequest(image: image, type: "meal")
        return try parseJSON(responseText)
    }

    func analyzeNutritionLabel(_ image: UIImage) async throws -> LabelAnalysisResponse {
        let responseText = try await sendAnalysisRequest(image: image, type: "label")
        return try parseJSON(responseText)
    }

    func analyzeRecipe(_ image: UIImage) async throws -> RecipeAnalysisResponse {
        let responseText = try await sendAnalysisRequest(image: image, type: "recipe")
        return try parseJSON(responseText)
    }

    // MARK: - Private

    private func sendAnalysisRequest(image: UIImage, type: String) async throws -> String {
        // Process image on a background thread to avoid blocking main
        let prepared: (base64: String, mediaType: String) = try await Task.detached {
            guard let result = ImageProcessor.prepareForAPI(image) else {
                throw NutriLensError.imageProcessingFailed
            }
            return result
        }.value

        var request = URLRequest(url: analyzeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConstants.appToken, forHTTPHeaderField: "X-App-Token")
        request.timeoutInterval = 60

        // Build JSON body by writing directly to Data to minimize copies of the base64 string
        var bodyData = Data()
        bodyData.append(Data("{\"type\":\"\(type)\",\"mediaType\":\"\(prepared.mediaType)\",\"image\":\"".utf8))
        bodyData.append(Data(prepared.base64.utf8))
        bodyData.append(Data("\"}".utf8))
        request.httpBody = bodyData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw NutriLensError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NutriLensError.unexpectedResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NutriLensError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // The Worker returns the Anthropic response as-is, so parse the same way
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw NutriLensError.unexpectedResponse
        }

        return text
    }

    private func parseJSON<T: Decodable>(_ text: String) throws -> T {
        // Claude sometimes wraps JSON in markdown code blocks
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw NutriLensError.jsonParsingFailed("Could not convert text to data")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NutriLensError.jsonParsingFailed(error.localizedDescription)
        }
    }
}
