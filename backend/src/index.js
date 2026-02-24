const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";
const MODEL_SONNET = "claude-sonnet-4-20250514";
const MODEL_HAIKU = "claude-haiku-4-5-20251001";
const DAILY_SONNET_LIMIT = 15;

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
    "Access-Control-Expose-Headers": "X-Model-Used",
  };
}

function getSonnetKey(request) {
  const ip = request.headers.get("CF-Connecting-IP") || "unknown";
  const date = new Date().toISOString().slice(0, 10);
  return `sonnet:${ip}:${date}`;
}

async function canUseSonnet(request, env) {
  try {
    const key = getSonnetKey(request);
    const count = parseInt(await env.RATE_LIMIT.get(key)) || 0;
    return count < DAILY_SONNET_LIMIT;
  } catch {
    return true; // fail-open: allow Sonnet if KV is unavailable
  }
}

async function incrementSonnetUsage(request, env) {
  try {
    const key = getSonnetKey(request);
    const count = parseInt(await env.RATE_LIMIT.get(key)) || 0;
    await env.RATE_LIMIT.put(key, String(count + 1), { expirationTtl: 86400 });
  } catch {
    // best-effort; don't block the request if KV write fails
  }
}

async function handleAnalyze(request, body, env) {
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

  // Select model: Sonnet for meal/recipe (visual), Haiku for label (text OCR)
  let model = MODEL_HAIKU;
  if (type === "meal" || type === "recipe") {
    const useSonnet = await canUseSonnet(request, env);
    model = useSonnet ? MODEL_SONNET : MODEL_HAIKU;
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
    model,
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

    // Track Sonnet usage after successful response
    if (model === MODEL_SONNET) {
      await incrementSonnetUsage(request, env);
    }

    const headers = corsHeaders();
    headers["X-Model-Used"] = model;

    return Response.json(responseData, {
      status: anthropicResponse.status,
      headers,
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
    model: MODEL_HAIKU,
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

    const headers = corsHeaders();
    headers["X-Model-Used"] = MODEL_HAIKU;

    return Response.json(responseData, {
      status: anthropicResponse.status,
      headers,
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
<p>MealSight collects the following data to provide nutrition tracking and analysis:</p>
<ul>
  <li><strong>Meal photos:</strong> Photos you take or select for AI-powered nutritional analysis, including single-photo and multi-photo meal scans, nutrition label scans, and recipe scans.</li>
  <li><strong>Nutrition data:</strong> Calorie, macronutrient (protein, carbs, fat), and micronutrient (fiber, sugar, sodium, cholesterol, saturated fat, trans fat, vitamins, minerals) information from your logged meals.</li>
  <li><strong>Body profile:</strong> Optional height, weight, age, biological sex, and activity level used for daily goal and TDEE calculations.</li>
  <li><strong>Dietary preferences:</strong> Dietary restrictions you set (e.g., vegetarian, vegan, gluten-free, dairy-free, nut-free, shellfish-free, egg-free, soy-free, low sodium, halal, kosher) used for dietary alert detection and AI Coach suggestions.</li>
  <li><strong>Health data:</strong> If you enable Apple Health integration, we read your weight and write dietary energy, protein, carbohydrates, and fat to Apple Health.</li>
  <li><strong>Feedback data:</strong> Accuracy ratings you provide on AI meal analysis results and any feedback you submit through the app.</li>
  <li><strong>App preferences:</strong> Meal reminder times, notification settings, AI consent status, appearance preferences, and onboarding status stored locally.</li>
</ul>

<h2>2. How We Use Your Data</h2>
<ul>
  <li><strong>AI Meal Analysis:</strong> When you scan a meal, nutrition label, or recipe, your photo is sent to Anthropic's Claude API for nutritional analysis. For multi-photo scans, multiple images are sent together. The images are processed to generate calorie and nutrient estimates, dietary flags, and a confidence score, then the results are returned to your device.</li>
  <li><strong>AI Coach:</strong> Your daily nutrition progress (calories, protein, carbs, fat, and their targets), current logging streak, time of day, and dietary restrictions are sent to Anthropic's Claude API to generate motivational tips, actionable advice, and meal suggestions. No photos or personal identifiers are included in coach requests.</li>
  <li><strong>Barcode Lookup:</strong> When you scan a barcode, the barcode number is sent to the OpenFoodFacts API to retrieve product nutrition data. No personal data is included.</li>
  <li><strong>Text Food Search:</strong> Food search queries you type are sent to the USDA FoodData Central API to retrieve matching food items and their nutritional data. Only the search text is transmitted.</li>
  <li><strong>Smart Insights:</strong> Your meal history is analyzed locally on your device to generate nutrition insights, eating pattern analysis, macro balance reports, and goal suggestions. This analysis happens entirely on-device.</li>
  <li><strong>Siri Shortcuts:</strong> If you use Siri Shortcuts (today's summary, calories remaining), MealSight reads your local meal data to respond. No data is sent to external services through Siri.</li>
  <li><strong>Widgets:</strong> Home screen and lock screen widgets display your daily calorie and macro progress. Widget data is read from your local meal history and refreshed periodically.</li>
  <li><strong>Notifications:</strong> If you enable meal reminders, notification times are stored locally. Notifications are scheduled through Apple's local notification system and do not involve any external servers.</li>
  <li><strong>Local Storage:</strong> Your meal history, goals, body profile, weight log, achievements, streaks, and preferences are stored locally on your device using Apple's SwiftData framework.</li>
</ul>

<h2>3. Third-Party Data Sharing</h2>
<p>We share data with the following third parties solely for app functionality:</p>
<ul>
  <li><strong>Anthropic (Claude API):</strong> Receives meal/label/recipe photos (base64-encoded) for AI nutritional analysis, and receives daily nutrition progress summaries for AI coaching. Anthropic does not use API data to train AI models. Images are processed in real time and are not stored beyond what is needed to complete the request. See <a href="https://www.anthropic.com/privacy">Anthropic's Privacy Policy</a>.</li>
  <li><strong>USDA FoodData Central:</strong> Receives text search queries for food nutrition lookup. No personal data is included in these requests.</li>
  <li><strong>OpenFoodFacts:</strong> Receives barcode numbers for product nutrition lookup. No personal data is included.</li>
  <li><strong>Apple (StoreKit):</strong> Processes in-app subscription purchases per Apple's policies.</li>
  <li><strong>Apple (HealthKit):</strong> If you grant permission, MealSight writes dietary nutrients to Apple Health and reads your weight. This data exchange is governed by Apple's privacy policies.</li>
</ul>
<p>We do not sell, rent, or share your personal data with third parties for advertising or marketing purposes. Health and fitness data is never used for advertising, marketing, or use-based data mining, in compliance with Apple's App Store guidelines.</p>
<p>We do not use any third-party analytics, crash reporting, or tracking SDKs. No usage data is sent to external analytics services.</p>

<h2>4. Data Storage and Security</h2>
<ul>
  <li>All personal data (meals, photos, goals, body profile, dietary restrictions, weight log, achievements, streaks) is stored locally on your device.</li>
  <li>Personal health information is not stored in iCloud.</li>
  <li>All data transmitted to third-party APIs (Anthropic, USDA, OpenFoodFacts) uses HTTPS encryption in transit.</li>
  <li>No user accounts are created — there are no passwords, emails, or credentials collected or stored.</li>
  <li>Meal photos are stored in the app's local data container and are not accessible to other apps.</li>
  <li>Feedback you submit is stored on our server with a random identifier only — no personal information is attached.</li>
</ul>

<h2>5. Data Retention and Deletion</h2>
<p>Since all data is stored locally on your device, you have full control:</p>
<ul>
  <li>Delete individual meals by swiping to delete in the app.</li>
  <li>Delete all app data by uninstalling MealSight from your device.</li>
  <li>Photos sent for AI analysis are processed in real time and not retained by Anthropic beyond the API request.</li>
  <li>Revoke HealthKit permissions at any time through iOS Settings > Health > Data Access.</li>
  <li>Withdraw AI consent at any time in the app's Settings, which will prevent further photo analysis.</li>
</ul>

<h2>6. Your Rights</h2>
<p>You have the right to:</p>
<ul>
  <li>Access all your data (stored locally on your device).</li>
  <li>Delete your data at any time by removing meals or uninstalling the app.</li>
  <li>Opt out of AI analysis by not using the scan feature or withdrawing AI consent in Settings.</li>
  <li>Opt out of HealthKit integration by revoking permissions in iOS Settings.</li>
  <li>Disable notifications and Siri Shortcuts at any time.</li>
</ul>

<h2>7. Children's Privacy</h2>
<p>MealSight is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you believe a child has provided data through the app, please contact us.</p>

<h2>8. Changes to This Policy</h2>
<p>We may update this Privacy Policy from time to time. Changes will be reflected by the "Last updated" date at the top of this page.</p>

<h2>9. Contact</h2>
<p>If you have questions about this Privacy Policy, contact us at:</p>
<p><a href="mailto:nutrilenshealth@gmail.com">nutrilenshealth@gmail.com</a></p>
`);
}

function termsPage() {
  return htmlPage("Terms of Use", `
<p>By downloading or using MealSight ("the App"), you agree to these Terms of Use. If you do not agree, do not use the App.</p>

<h2>1. Description of Service</h2>
<p>MealSight is a nutrition tracking app that helps you understand your eating habits. The App provides:</p>
<ul>
  <li><strong>AI Photo Analysis:</strong> Scan meals, nutrition labels, and recipes using your camera or photo library. Photos are analyzed by AI to estimate nutritional content. Supports single-photo and multi-photo meal scans.</li>
  <li><strong>Barcode Scanning:</strong> Scan product barcodes to retrieve nutrition data from the OpenFoodFacts database.</li>
  <li><strong>AI Coach:</strong> Personalized motivational tips, actionable nutrition advice, and meal suggestions based on your daily progress and dietary restrictions.</li>
  <li><strong>Text Food Search:</strong> Search and log meals via the USDA FoodData Central database.</li>
  <li><strong>Smart Insights:</strong> On-device analysis of your eating patterns, macro balance, meal timing, and nutrition trends.</li>
  <li><strong>Interactive Charts:</strong> Visualize your calorie and macronutrient trends over time with daily, weekly, and monthly views.</li>
  <li><strong>Dietary Alerts:</strong> Automatic detection of foods that may conflict with your dietary restrictions.</li>
  <li><strong>Health Integration:</strong> Optional Apple Health sync for weight tracking and nutrition data sharing.</li>
  <li><strong>Siri Shortcuts:</strong> Voice-activated commands to check daily summaries and view remaining calories.</li>
  <li><strong>Widgets:</strong> Home screen and lock screen widgets showing daily nutrition progress.</li>
  <li><strong>Achievements:</strong> Milestones and badges to track your nutrition logging progress and streaks.</li>
</ul>

<h2>2. Medical Disclaimer</h2>
<p><strong>MealSight is not a medical device.</strong> It is designed for general wellness and informational purposes only. It does not diagnose, treat, cure, or prevent any disease or medical condition.</p>
<p>Nutritional estimates are approximations generated by artificial intelligence and the USDA database. They may vary from actual values and should not be used as the sole basis for medical or dietary decisions.</p>
<p>Always consult your physician or a qualified healthcare professional before making dietary changes, especially if you have medical conditions (such as diabetes, kidney disease, or heart disease), food allergies, are pregnant or nursing, or have an eating disorder.</p>

<h2>3. AI-Generated Content</h2>
<p>The following features use artificial intelligence and produce AI-generated content:</p>
<ul>
  <li><strong>Meal/label/recipe photo analysis</strong> — calorie and nutrient estimates, food item identification, dietary flag detection, and confidence scores.</li>
  <li><strong>AI Coach</strong> — motivational messages, nutrition tips, and meal/recipe suggestions tailored to your dietary restrictions.</li>
  <li><strong>Smart Insights</strong> — eating pattern analysis and goal suggestions (generated on-device).</li>
</ul>
<p>All AI-generated content is for informational and general wellness purposes only. It is not personalized medical or nutritional advice and does not account for your complete medical history, allergies, medication interactions, or individual nutritional needs. AI suggestions may occasionally be inaccurate or inappropriate — always use your own judgment.</p>

<h2>4. Accuracy of Estimates</h2>
<p>Calorie and macronutrient estimates may vary by 20% or more from actual values depending on:</p>
<ul>
  <li>Portion size estimation from photos</li>
  <li>Food preparation methods and recipes</li>
  <li>Ingredient variations between brands</li>
  <li>Image quality and lighting conditions</li>
  <li>Limitations of AI image recognition</li>
</ul>
<p>Nutrition label scanning accuracy depends on label legibility and image clarity. Barcode scanning accuracy depends on the completeness of the OpenFoodFacts database. For precise nutritional information, refer to product nutrition labels or consult a registered dietitian.</p>

<h2>5. Dietary Alerts Disclaimer</h2>
<p>Dietary alert detection (e.g., gluten, dairy, nuts, shellfish, soy, eggs) is based on AI analysis and keyword matching. It may not detect all allergens or dietary conflicts. <strong>Do not rely solely on MealSight for allergen detection.</strong> Always verify ingredients independently if you have food allergies or sensitivities.</p>

<h2>6. Subscriptions</h2>
<ul>
  <li>MealSight offers an optional MealSight Pro subscription that unlocks unlimited scanning and all features.</li>
  <li>Payment is charged to your Apple ID account at confirmation of purchase.</li>
  <li>Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period.</li>
  <li>Your account will be charged for renewal within 24 hours prior to the end of the current period.</li>
  <li>Manage subscriptions and turn off auto-renewal in your Account Settings after purchase.</li>
  <li>Any unused portion of a free trial period will be forfeited upon purchase of a subscription.</li>
</ul>

<h2>7. No Professional Relationship</h2>
<p>Use of MealSight does not create a physician-patient, dietitian-client, or any other professional-client relationship. The information provided through this App, including AI Coach suggestions and Smart Insights, is for general educational and informational purposes only.</p>

<h2>8. Third-Party Services</h2>
<p>The App relies on the following third-party services:</p>
<ul>
  <li><strong>Anthropic (Claude API):</strong> Powers AI meal analysis and coaching. Governed by <a href="https://www.anthropic.com/terms">Anthropic's Terms</a>.</li>
  <li><strong>USDA FoodData Central:</strong> Provides food nutrition database for text search.</li>
  <li><strong>OpenFoodFacts:</strong> Provides product nutrition data for barcode scanning.</li>
  <li><strong>Apple HealthKit:</strong> Optional health data integration, governed by Apple's terms.</li>
  <li><strong>Apple StoreKit:</strong> Processes subscription purchases, governed by Apple's terms.</li>
</ul>
<p>We are not responsible for the availability, accuracy, or policies of third-party services. If a third-party service is temporarily unavailable, affected features may not function until the service is restored.</p>

<h2>9. Limitation of Liability</h2>
<p>To the maximum extent permitted by law, MealSight and its developer shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the App, including but not limited to:</p>
<ul>
  <li>Health outcomes based on nutritional estimates or AI suggestions</li>
  <li>Allergic reactions from undetected dietary conflicts</li>
  <li>Data loss due to device failure or app removal</li>
  <li>Inaccurate nutritional data from AI analysis or database lookups</li>
</ul>

<h2>10. Acceptable Use</h2>
<p>You agree not to misuse the App, attempt to reverse engineer it, circumvent subscription restrictions, or use it for any purpose other than personal nutrition tracking and wellness.</p>

<h2>11. Termination</h2>
<p>We reserve the right to terminate or suspend access to the App at any time for violation of these terms.</p>

<h2>12. Changes to Terms</h2>
<p>We may update these Terms from time to time. Continued use of the App after changes constitutes acceptance of the new terms.</p>

<h2>13. Contact</h2>
<p>Questions about these Terms? Contact us at:</p>
<p><a href="mailto:nutrilenshealth@gmail.com">nutrilenshealth@gmail.com</a></p>
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
      return handleAnalyze(request, body, env);
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
