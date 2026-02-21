import Foundation

enum ClaudePrompts {
    // MARK: - Meal Analysis

    static let mealAnalysisSystemPrompt = """
    You are a nutrition analysis expert. Analyze food photos and estimate nutritional content \
    for each visible food item. Be as accurate as possible with portion sizes based on visual cues. \
    If you are uncertain about a food item, reflect that in a lower confidence score. \
    Always respond with valid JSON matching the exact schema provided. Do not include any text outside the JSON.
    """

    static let mealAnalysisUserPrompt = """
    Analyze this meal photo. For each food item visible, estimate:
    - The food name
    - Approximate quantity/portion size
    - Calories (kcal)
    - Protein (grams)
    - Carbohydrates (grams)
    - Fat (grams)
    - Fiber (grams)
    - Sugar (grams)

    Also provide:
    - A suggested name for this meal
    - An overall confidence score (0.0 to 1.0) for your estimates

    Also flag any common dietary concerns (e.g. "contains gluten", "contains dairy", "contains nuts", "contains shellfish", "contains eggs", "contains soy", "high sodium", "not vegetarian", "not vegan").

    Respond ONLY with JSON in this exact format:
    {
      "mealName": "string",
      "confidence": 0.0,
      "dietaryFlags": ["string"],
      "items": [
        {
          "name": "string",
          "quantity": "string",
          "nutrients": {
            "calories": 0.0,
            "proteinGrams": 0.0,
            "carbsGrams": 0.0,
            "fatGrams": 0.0,
            "fiberGrams": 0.0,
            "sugarGrams": 0.0
          }
        }
      ]
    }
    """

    // MARK: - Nutrition Label

    static let labelAnalysisSystemPrompt = """
    You are an expert at reading nutrition facts labels. Extract all nutritional information \
    accurately from the label photo. Read every value carefully, including serving size and \
    servings per container. Always respond with valid JSON matching the exact schema provided. \
    Do not include any text outside the JSON.
    """

    static let labelAnalysisUserPrompt = """
    Extract all nutritional information from this nutrition facts label photo. Read every value carefully.

    Respond ONLY with JSON in this exact format:
    {
      "productName": "string",
      "brandName": "string or null",
      "servingSize": "string",
      "servingsPerContainer": 0.0,
      "nutrients": {
        "calories": 0.0,
        "proteinGrams": 0.0,
        "carbsGrams": 0.0,
        "fatGrams": 0.0,
        "fiberGrams": 0.0,
        "sugarGrams": 0.0,
        "sodiumMilligrams": 0.0,
        "cholesterolMilligrams": 0.0,
        "saturatedFatGrams": 0.0,
        "transFatGrams": 0.0
      }
    }
    """

    // MARK: - Recipe Analysis

    static let recipeAnalysisSystemPrompt = """
    You are a nutrition analysis expert specializing in recipe analysis. Analyze photos of recipes \
    (from cookbooks, websites, handwritten notes, or screens) and estimate nutritional content per \
    serving for each ingredient. Be as accurate as possible with quantities. If you are uncertain, \
    reflect that in a lower confidence score. Always respond with valid JSON matching the exact \
    schema provided. Do not include any text outside the JSON.
    """

    static let recipeAnalysisUserPrompt = """
    Analyze this recipe photo. For each ingredient or component, estimate:
    - The ingredient name
    - Approximate quantity used in the full recipe
    - Calories (kcal) for the full recipe amount
    - Protein (grams)
    - Carbohydrates (grams)
    - Fat (grams)
    - Fiber (grams)
    - Sugar (grams)

    Also provide:
    - A suggested name for this recipe
    - An overall confidence score (0.0 to 1.0) for your estimates
    - Estimated number of servings this recipe makes
    - Dietary flags (e.g. "contains gluten", "contains dairy", "contains nuts", "contains shellfish", "contains eggs", "contains soy", "high sodium", "not vegetarian", "not vegan")

    Respond ONLY with JSON in this exact format:
    {
      "mealName": "string",
      "confidence": 0.0,
      "estimatedServings": 4,
      "dietaryFlags": ["string"],
      "items": [
        {
          "name": "string",
          "quantity": "string",
          "nutrients": {
            "calories": 0.0,
            "proteinGrams": 0.0,
            "carbsGrams": 0.0,
            "fatGrams": 0.0,
            "fiberGrams": 0.0,
            "sugarGrams": 0.0
          }
        }
      ]
    }
    """
}
