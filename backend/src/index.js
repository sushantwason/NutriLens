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
    "You are a friendly, concise nutrition coach inside the MealSight app. Give a brief motivational nudge based on the user's daily nutrition progress. Be encouraging, specific, and actionable. Also suggest a specific meal or recipe that would help them hit their remaining macro targets for the day. Always respond with valid JSON matching the exact schema provided. Do not include any text outside the JSON.",
  userTemplate: (data) => `Here is the user's nutrition progress for today:

Calories: ${data.calories} / ${data.calorieTarget} kcal
Protein: ${data.protein} / ${data.proteinTarget} g
Carbs: ${data.carbs} / ${data.carbsTarget} g
Fat: ${data.fat} / ${data.fatTarget} g
Current streak: ${data.streak} days
Time of day: ${data.timeOfDay}
${data.restrictions ? `Dietary restrictions: ${data.restrictions}` : ""}

Based on this progress, provide:
1. A brief motivational message (1-2 sentences)
2. A relevant emoji
3. A specific actionable tip
4. A meal or recipe suggestion that fits the user's remaining calorie/macro budget for the day. Consider the time of day and any dietary restrictions.

Respond ONLY with JSON in this exact format:
{
  "message": "string",
  "emoji": "string",
  "tip": "string",
  "mealSuggestion": {
    "name": "string",
    "description": "string",
    "estimatedCalories": 0
  }
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

  try {
    const id = `${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
    const entry = {
      id,
      category,
      message: trimmedMessage,
      appVersion: appVersion || "MealSight",
      timestamp: new Date().toISOString(),
    };

    await env.FEEDBACK.put(id, JSON.stringify(entry));

    return Response.json(
      { success: true },
      { status: 200, headers: corsHeaders() }
    );
  } catch (err) {
    return Response.json(
      { error: "Failed to save feedback", detail: err.message },
      { status: 500, headers: corsHeaders() }
    );
  }
}

function htmlPage(title, content) {
  return new Response(
    `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${title} — MealSight</title>
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;line-height:1.6;color:#1a1a1a;background:#fafafa;padding:20px}
  .container{max-width:720px;margin:0 auto;background:#fff;border-radius:16px;padding:32px 28px;box-shadow:0 1px 3px rgba(0,0,0,0.08)}
  h1{font-size:24px;margin-bottom:8px;color:#1a1a1a}
  h2{font-size:18px;margin-top:28px;margin-bottom:8px;color:#2d6a4f}
  p,li{font-size:15px;color:#444;margin-bottom:8px}
  ul{padding-left:20px;margin-bottom:12px}
  .updated{font-size:13px;color:#888;margin-bottom:24px}
  .logo{font-size:28px;margin-bottom:16px}
  a{color:#2d6a4f}
</style>
</head>
<body>
<div class="container">
<div class="logo">🥗</div>
<h1>${title}</h1>
<p class="updated">Last updated: February 22, 2026</p>
${content}
</div>
</body>
</html>`,
    { status: 200, headers: { "Content-Type": "text/html; charset=utf-8" } }
  );
}

function privacyPage() {
  return htmlPage("Privacy Policy", `
<p>MealSight ("the App") is developed by Sushant Wason. This Privacy Policy explains how we collect, use, and protect your information.</p>

<h2>1. Information We Collect</h2>
<p>MealSight collects the following data to provide nutrition tracking:</p>
<ul>
  <li><strong>Meal photos:</strong> Photos you take or select for AI-powered nutritional analysis.</li>
  <li><strong>Nutrition data:</strong> Calorie and macronutrient information from your logged meals.</li>
  <li><strong>Body profile:</strong> Optional weight, height, age, and activity level for goal calculations.</li>
  <li><strong>Health data:</strong> If you enable Apple Health integration, we read weight and write nutrition/water data.</li>
  <li><strong>Usage data:</strong> Meal logging streaks, accuracy feedback ratings, and feature usage.</li>
</ul>

<h2>2. How We Use Your Data</h2>
<ul>
  <li><strong>AI Analysis:</strong> When you scan a meal, label, or recipe, your photo is sent to Anthropic's Claude API for nutritional analysis. The image is processed to generate estimates and the results are returned to your device.</li>
  <li><strong>AI Coach:</strong> Your daily nutrition progress (calories, macros, streak) is sent to Anthropic's Claude API to generate motivational tips and meal suggestions. No photos or personal identifiers are included.</li>
  <li><strong>Text Search:</strong> Food search queries are sent to the USDA FoodData Central API to retrieve nutritional data.</li>
  <li><strong>Local Storage:</strong> Your meal history, goals, body profile, and preferences are stored locally on your device using Apple's SwiftData framework.</li>
</ul>

<h2>3. Third-Party Data Sharing</h2>
<p>We share data with the following third parties solely for app functionality:</p>
<ul>
  <li><strong>Anthropic (Claude API):</strong> Receives meal photos and nutrition progress for AI analysis. Anthropic does not use API data to train AI models. Images are not stored beyond what is needed to complete the request. See <a href="https://www.anthropic.com/privacy">Anthropic's Privacy Policy</a>.</li>
  <li><strong>USDA FoodData Central:</strong> Receives text search queries for food nutrition lookup.</li>
  <li><strong>Apple (StoreKit, HealthKit):</strong> Processes subscriptions and health data sync per Apple's policies.</li>
</ul>
<p>We do not sell, rent, or share your personal data with third parties for advertising or marketing purposes. Health and fitness data is never used for advertising or data mining.</p>

<h2>4. Data Storage and Security</h2>
<ul>
  <li>All personal data (meals, goals, body profile) is stored locally on your device.</li>
  <li>Personal health information is not stored in iCloud.</li>
  <li>Data transmitted to third-party APIs uses HTTPS encryption.</li>
  <li>No user accounts are created — there are no passwords or credentials stored.</li>
</ul>

<h2>5. Data Retention and Deletion</h2>
<p>Since all data is stored locally on your device, you have full control:</p>
<ul>
  <li>Delete individual meals by swiping to delete in the app.</li>
  <li>Delete all app data by uninstalling MealSight from your device.</li>
  <li>Photos sent for AI analysis are processed in real time and not retained by Anthropic beyond the API request.</li>
</ul>

<h2>6. Your Rights</h2>
<p>You have the right to:</p>
<ul>
  <li>Access all your data (stored locally on your device).</li>
  <li>Delete your data at any time.</li>
  <li>Opt out of AI analysis by not using the scan feature.</li>
  <li>Withdraw AI consent at any time in Settings.</li>
  <li>Export your data using the in-app Export feature.</li>
</ul>

<h2>7. Children's Privacy</h2>
<p>MealSight is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you believe a child has provided us with data, please contact us.</p>

<h2>8. Changes to This Policy</h2>
<p>We may update this Privacy Policy from time to time. Changes will be reflected by the "Last updated" date at the top of this page.</p>

<h2>9. Contact</h2>
<p>If you have questions about this Privacy Policy, contact us at:</p>
<p><a href="mailto:support@mealsightapp.com">support@mealsightapp.com</a></p>
`);
}

function termsPage() {
  return htmlPage("Terms of Use", `
<p>By downloading or using MealSight ("the App"), you agree to these Terms of Use.</p>

<h2>1. Description of Service</h2>
<p>MealSight is a nutrition tracking app that uses AI-powered photo analysis to estimate calorie and macronutrient content of meals. The App also provides an AI Coach feature with motivational tips and meal suggestions.</p>

<h2>2. Medical Disclaimer</h2>
<p><strong>MealSight is not a medical device.</strong> It does not diagnose, treat, cure, or prevent any disease or medical condition. Nutritional estimates are approximations generated by artificial intelligence and may vary from actual values. Do not rely on this App as a substitute for professional medical advice, diagnosis, or treatment.</p>
<p>Always consult your physician or a qualified healthcare professional before making dietary changes, especially if you have medical conditions, food allergies, are pregnant or nursing, or have an eating disorder.</p>

<h2>3. AI-Generated Content</h2>
<p>Nutritional estimates, meal suggestions, coaching tips, and other content generated by AI are for informational and general wellness purposes only. They are not personalized medical or nutritional advice and do not account for your complete medical history, allergies, or medication interactions.</p>

<h2>4. Accuracy of Estimates</h2>
<p>Calorie and macronutrient estimates may vary by 20% or more from actual values depending on portion sizes, cooking methods, specific ingredients, and image quality. For precise nutritional information, consult product nutrition labels or a registered dietitian.</p>

<h2>5. Subscriptions</h2>
<ul>
  <li>Payment is charged to your Apple ID account at confirmation of purchase.</li>
  <li>Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period.</li>
  <li>Your account will be charged for renewal within 24 hours prior to the end of the current period.</li>
  <li>Manage subscriptions and turn off auto-renewal in your Account Settings.</li>
  <li>Any unused portion of a free trial period will be forfeited upon purchase of a subscription.</li>
</ul>

<h2>6. No Professional Relationship</h2>
<p>Use of MealSight does not create a physician-patient, dietitian-client, or any other professional-client relationship.</p>

<h2>7. Third-Party Services</h2>
<p>The App uses Anthropic's Claude API for AI analysis and the USDA FoodData Central database for text-based food search. These services are governed by their own terms and privacy policies.</p>

<h2>8. Limitation of Liability</h2>
<p>To the maximum extent permitted by law, MealSight and its developer shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the App, including but not limited to health outcomes based on nutritional estimates.</p>

<h2>9. Acceptable Use</h2>
<p>You agree not to misuse the App, attempt to reverse engineer it, or use it for any purpose other than personal nutrition tracking.</p>

<h2>10. Termination</h2>
<p>We reserve the right to terminate or suspend access to the App at any time for violation of these terms.</p>

<h2>11. Changes to Terms</h2>
<p>We may update these Terms from time to time. Continued use of the App after changes constitutes acceptance of the new terms.</p>

<h2>12. Contact</h2>
<p>Questions about these Terms? Contact us at:</p>
<p><a href="mailto:support@mealsightapp.com">support@mealsightapp.com</a></p>
`);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    // Serve legal pages (GET)
    if (request.method === "GET") {
      if (url.pathname === "/privacy") return privacyPage();
      if (url.pathname === "/terms") return termsPage();
      return Response.json({ error: "Not found" }, { status: 404 });
    }

    if (request.method !== "POST") {
      return Response.json(
        { error: "Not found" },
        { status: 404, headers: corsHeaders() }
      );
    }

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
