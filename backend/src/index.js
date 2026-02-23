const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";
const MODEL = "claude-sonnet-4-20250514";

const PROMPTS = {
  meal: {
    system:
      "You are a nutrition analysis expert. Analyze food photos and estimate nutritional content for each visible food item. Be as accurate as possible with portion sizes based on visual cues. If you are uncertain about a food item, reflect that in a lower confidence score. Always respond with valid JSON matching the exact schema provided. Do not include any text outside the JSON.",
    user: `Analyze this meal photo. For each food item visible, estimate:
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
- Dietary flags for common concerns (e.g. "contains gluten", "contains dairy", "contains nuts", "contains shellfish", "contains eggs", "contains soy", "high sodium", "not vegetarian", "not vegan")

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
}`,
  },
  label: {
    system:
      "You are an expert at reading nutrition facts labels. Extract all nutritional information accurately from the label photo. Read every value carefully, including serving size and servings per container. Always respond with valid JSON matching the exact schema provided. Do not include any text outside the JSON.",
    user: `Extract all nutritional information from this nutrition facts label photo. Read every value carefully.

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
}`,
  },
  recipe: {
    system:
      "You are a nutrition analysis expert specializing in recipe analysis. Analyze photos of recipes (from cookbooks, websites, handwritten notes, or screens) and estimate nutritional content for each ingredient. Be as accurate as possible with quantities. If you are uncertain, reflect that in a lower confidence score. Always respond with valid JSON matching the exact schema provided. Do not include any text outside the JSON.",
    user: `Analyze this recipe photo. For each ingredient or component, estimate:
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
- Dietary flags for common concerns (e.g. "contains gluten", "contains dairy", "contains nuts", "contains shellfish", "contains eggs", "contains soy", "high sodium", "not vegetarian", "not vegan")

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
}`,
  },
};

const COACH_PROMPT = {
  system:
    "You are a friendly, concise nutrition coach inside the NutriLens app. Give a brief motivational nudge based on the user's daily nutrition progress. Be encouraging, specific, and actionable. Always respond with valid JSON matching the exact schema provided. Do not include any text outside the JSON.",
  userTemplate: (data) => `Here is the user's nutrition progress for today:

Calories: ${data.calories} / ${data.calorieTarget} kcal
Protein: ${data.protein} / ${data.proteinTarget} g
Carbs: ${data.carbs} / ${data.carbsTarget} g
Fat: ${data.fat} / ${data.fatTarget} g
Current streak: ${data.streak} days
Time of day: ${data.timeOfDay}
${data.restrictions ? `Dietary restrictions: ${data.restrictions}` : ""}

Based on this progress, provide a brief motivational message (1-2 sentences), a relevant emoji, and a specific actionable tip.

Respond ONLY with JSON in this exact format:
{
  "message": "string",
  "emoji": "string",
  "tip": "string"
}`,
};

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-App-Token",
  };
}

async function handleAnalyze(body, env) {
  const { type, image, mediaType, images } = body;

  // Support both single image (image/mediaType) and multi-image (images array)
  let imageEntries = [];
  if (images && Array.isArray(images) && images.length > 0) {
    for (const img of images) {
      if (!img.image || !img.mediaType) {
        return Response.json(
          { error: "Each entry in images must have image and mediaType" },
          { status: 400, headers: corsHeaders() }
        );
      }
      imageEntries.push({ image: img.image, mediaType: img.mediaType });
    }
  } else if (image && mediaType) {
    imageEntries.push({ image, mediaType });
  } else {
    return Response.json(
      { error: "Missing required fields: provide (image, mediaType) or images array" },
      { status: 400, headers: corsHeaders() }
    );
  }

  const prompt = PROMPTS[type];
  if (!prompt) {
    return Response.json(
      { error: 'Invalid type. Must be "meal", "label", or "recipe".' },
      { status: 400, headers: corsHeaders() }
    );
  }

  // Build content blocks: one image block per photo, then the text prompt
  const contentBlocks = imageEntries.map((entry) => ({
    type: "image",
    source: {
      type: "base64",
      media_type: entry.mediaType,
      data: entry.image,
    },
  }));
  contentBlocks.push({
    type: "text",
    text: prompt.user,
  });

  const anthropicBody = {
    model: MODEL,
    max_tokens: 2048,
    system: prompt.system,
    messages: [
      {
        role: "user",
        content: contentBlocks,
      },
    ],
  };

  try {
    const anthropicResponse = await fetch(ANTHROPIC_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify(anthropicBody),
    });

    const responseData = await anthropicResponse.json();

    return Response.json(responseData, {
      status: anthropicResponse.status,
      headers: corsHeaders(),
    });
  } catch (err) {
    return Response.json(
      { error: "Failed to reach Anthropic API", detail: err.message },
      { status: 502, headers: corsHeaders() }
    );
  }
}

async function handleCoach(body, env) {
  const { progress, streak, timeOfDay, restrictions } = body;

  if (!progress) {
    return Response.json(
      { error: "Missing required field: progress" },
      { status: 400, headers: corsHeaders() }
    );
  }

  const userPrompt = COACH_PROMPT.userTemplate({
    calories: progress.calories || 0,
    calorieTarget: progress.calorieTarget || 2000,
    protein: progress.protein || 0,
    proteinTarget: progress.proteinTarget || 150,
    carbs: progress.carbs || 0,
    carbsTarget: progress.carbsTarget || 250,
    fat: progress.fat || 0,
    fatTarget: progress.fatTarget || 65,
    streak: streak || 0,
    timeOfDay: timeOfDay || "afternoon",
    restrictions: restrictions || "",
  });

  const anthropicBody = {
    model: MODEL,
    max_tokens: 256,
    system: COACH_PROMPT.system,
    messages: [
      {
        role: "user",
        content: userPrompt,
      },
    ],
  };

  try {
    const anthropicResponse = await fetch(ANTHROPIC_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify(anthropicBody),
    });

    const responseData = await anthropicResponse.json();

    return Response.json(responseData, {
      status: anthropicResponse.status,
      headers: corsHeaders(),
    });
  } catch (err) {
    return Response.json(
      { error: "Failed to reach Anthropic API", detail: err.message },
      { status: 502, headers: corsHeaders() }
    );
  }
}

async function handleFeedback(body, env) {
  const { category, message, appVersion } = body;

  if (!category || !message) {
    return Response.json(
      { error: "Missing required fields: category, message" },
      { status: 400, headers: corsHeaders() }
    );
  }

  const trimmedMessage = message.trim();
  if (trimmedMessage.length === 0) {
    return Response.json(
      { error: "Message cannot be empty" },
      { status: 400, headers: corsHeaders() }
    );
  }

  const subject = `[${category}] MealSight Feedback`;
  const emailBody = `Category: ${category}\n\n${trimmedMessage}\n\n---\n${appVersion || "MealSight"}`;

  try {
    const mailResponse = await fetch("https://api.mailchannels.net/tx/v1/send", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        personalizations: [
          {
            to: [{ email: "nutrilenshealth@gmail.com", name: "MealSight Team" }],
          },
        ],
        from: {
          email: "feedback@mealsightapp.com",
          name: "MealSight Feedback",
        },
        subject: subject,
        content: [
          {
            type: "text/plain",
            value: emailBody,
          },
        ],
      }),
    });

    if (mailResponse.status === 202 || mailResponse.status === 200) {
      return Response.json(
        { success: true },
        { status: 200, headers: corsHeaders() }
      );
    } else {
      const errorText = await mailResponse.text();
      console.error("MailChannels error:", mailResponse.status, errorText);
      return Response.json(
        { error: "Failed to send feedback email" },
        { status: 502, headers: corsHeaders() }
      );
    }
  } catch (err) {
    return Response.json(
      { error: "Failed to send feedback", detail: err.message },
      { status: 502, headers: corsHeaders() }
    );
  }
}

export default {
  async fetch(request, env) {
    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    if (request.method !== "POST") {
      return Response.json(
        { error: "Not found" },
        { status: 404, headers: corsHeaders() }
      );
    }

    const url = new URL(request.url);

    // Validate app token
    const appToken = request.headers.get("X-App-Token");
    if (!appToken || appToken !== env.APP_TOKEN) {
      return Response.json(
        { error: "Unauthorized" },
        { status: 401, headers: corsHeaders() }
      );
    }

    // Parse request body
    let body;
    try {
      body = await request.json();
    } catch {
      return Response.json(
        { error: "Invalid JSON body" },
        { status: 400, headers: corsHeaders() }
      );
    }

    // Route to handler
    if (url.pathname === "/api/analyze") {
      return handleAnalyze(body, env);
    } else if (url.pathname === "/api/coach") {
      return handleCoach(body, env);
    } else if (url.pathname === "/api/feedback") {
      return handleFeedback(body, env);
    } else {
      return Response.json(
        { error: "Not found" },
        { status: 404, headers: corsHeaders() }
      );
    }
  },
};
