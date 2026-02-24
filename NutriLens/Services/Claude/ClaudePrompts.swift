import Foundation

enum ClaudePrompts {
    // MARK: - Meal Analysis

    static let mealAnalysisSystemPrompt = """
    You are a nutrition analysis expert. Analyze food photos and estimate nutritional content \
    for each visible food item. Be as accurate as possible with portion sizes based on visual cues. \
    Include macronutrients and estimate micronutrients (vitamins and minerals) based on known \
    nutritional profiles of identified foods. If you are uncertain about a food item, reflect that \
    in a lower confidence score. Always respond with valid JSON matching the exact schema provided. \
    Do not include any text outside the JSON.
    """

    static let mealAnalysisUserPrompt = """
    Analyze this meal photo. For each food item visible, estimate:
    - The food name
    - Approximate quantity/portion size
    - Macronutrients: Calories (kcal), Protein (g), Carbs (g), Fat (g), Fiber (g), Sugar (g), \
    Sodium (mg), Cholesterol (mg), Saturated Fat (g), Trans Fat (g)
    - Micronutrients: Vitamin A (mcg), Vitamin C (mg), Vitamin D (mcg), Vitamin E (mg), \
    Vitamin K (mcg), Vitamin B6 (mg), Vitamin B12 (mcg), Folate (mcg), \
    Calcium (mg), Iron (mg), Magnesium (mg), Potassium (mg), Zinc (mg)

    Also provide:
    - A suggested name for this meal
    - An overall confidence score (0.0 to 1.0) for your estimates

    Respond ONLY with JSON in this exact format:
    {
      "mealName": "string",
      "confidence": 0.0,
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
            "sugarGrams": 0.0,
            "sodiumMilligrams": 0.0,
            "cholesterolMilligrams": 0.0,
            "saturatedFatGrams": 0.0,
            "transFatGrams": 0.0,
            "vitaminAMicrograms": 0.0,
            "vitaminCMilligrams": 0.0,
            "vitaminDMicrograms": 0.0,
            "vitaminEMilligrams": 0.0,
            "vitaminKMicrograms": 0.0,
            "vitaminB6Milligrams": 0.0,
            "vitaminB12Micrograms": 0.0,
            "folateMicrograms": 0.0,
            "calciumMilligrams": 0.0,
            "ironMilligrams": 0.0,
            "magnesiumMilligrams": 0.0,
            "potassiumMilligrams": 0.0,
            "zincMilligrams": 0.0
          }
        }
      ]
    }
    """

    // MARK: - Nutrition Label

    static let labelAnalysisSystemPrompt = """
    You are an expert at reading nutrition facts labels. Extract all nutritional information \
    accurately from the label photo. Read every value carefully, including serving size and \
    servings per container. Extract micronutrients if listed on the label. \
    Always respond with valid JSON matching the exact schema provided. \
    Do not include any text outside the JSON.
    """

    static let labelAnalysisUserPrompt = """
    Extract all nutritional information from this nutrition facts label photo. Read every value carefully. \
    Include any micronutrient values listed on the label (vitamins and minerals).

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
        "transFatGrams": 0.0,
        "vitaminAMicrograms": 0.0,
        "vitaminCMilligrams": 0.0,
        "vitaminDMicrograms": 0.0,
        "vitaminEMilligrams": 0.0,
        "vitaminKMicrograms": 0.0,
        "vitaminB6Milligrams": 0.0,
        "vitaminB12Micrograms": 0.0,
        "folateMicrograms": 0.0,
        "calciumMilligrams": 0.0,
        "ironMilligrams": 0.0,
        "magnesiumMilligrams": 0.0,
        "potassiumMilligrams": 0.0,
        "zincMilligrams": 0.0
      }
    }
    """

    // MARK: - Recipe Analysis

    static let recipeAnalysisSystemPrompt = """
    You are a nutrition analysis expert specializing in recipe analysis. Analyze photos of recipes \
    (from cookbooks, websites, handwritten notes, or screens) and estimate nutritional content per \
    serving for each ingredient. Include micronutrient estimates based on known nutritional profiles. \
    Be as accurate as possible with quantities. If you are uncertain, \
    reflect that in a lower confidence score. Always respond with valid JSON matching the exact \
    schema provided. Do not include any text outside the JSON.
    """

    static let recipeAnalysisUserPrompt = """
    Analyze this recipe photo. For each ingredient or component, estimate:
    - The ingredient name
    - Approximate quantity used in the full recipe
    - Macronutrients: Calories (kcal), Protein (g), Carbs (g), Fat (g), Fiber (g), Sugar (g), \
    Sodium (mg), Cholesterol (mg), Saturated Fat (g), Trans Fat (g)
    - Micronutrients: Vitamin A (mcg), Vitamin C (mg), Vitamin D (mcg), Vitamin E (mg), \
    Vitamin K (mcg), Vitamin B6 (mg), Vitamin B12 (mcg), Folate (mcg), \
    Calcium (mg), Iron (mg), Magnesium (mg), Potassium (mg), Zinc (mg)

    Also provide:
    - A suggested name for this recipe
    - An overall confidence score (0.0 to 1.0) for your estimates
    - Estimated number of servings this recipe makes

    Respond ONLY with JSON in this exact format:
    {
      "mealName": "string",
      "confidence": 0.0,
      "estimatedServings": 4,
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
            "sugarGrams": 0.0,
            "sodiumMilligrams": 0.0,
            "cholesterolMilligrams": 0.0,
            "saturatedFatGrams": 0.0,
            "transFatGrams": 0.0,
            "vitaminAMicrograms": 0.0,
            "vitaminCMilligrams": 0.0,
            "vitaminDMicrograms": 0.0,
            "vitaminEMilligrams": 0.0,
            "vitaminKMicrograms": 0.0,
            "vitaminB6Milligrams": 0.0,
            "vitaminB12Micrograms": 0.0,
            "folateMicrograms": 0.0,
            "calciumMilligrams": 0.0,
            "ironMilligrams": 0.0,
            "magnesiumMilligrams": 0.0,
            "potassiumMilligrams": 0.0,
            "zincMilligrams": 0.0
          }
        }
      ]
    }
    """
}
