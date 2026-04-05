function callGeminiApi_(prompt) {
  const url = "https://generativelanguage.googleapis.com/v1beta/models/"
    + CONFIG.GEMINI_MODEL + ":generateContent?key=" + SECRET.GEMINI_API_KEY;

  const options = {
    method: "post",
    contentType: "application/json",
    payload: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0, maxOutputTokens: 512 },
    }),
    muteHttpExceptions: true,
  };

  for (let attempt = 1; attempt <= CONFIG.MAX_RETRIES; attempt++) {
    const response = UrlFetchApp.fetch(url, options);

    if (response.getResponseCode() !== 200) {
      Logger.log("Gemini error (%s), attempt %s/%s", response.getResponseCode(), attempt, CONFIG.MAX_RETRIES);
      continue;
    }

    try {
      const data = JSON.parse(response.getContentText());
      const text = data.candidates[0].content.parts[0].text;
      return JSON.parse(text.replace(/```json|```/g, "").trim());
    } catch (err) {
      Logger.log("Parse error, attempt %s/%s: %s", attempt, CONFIG.MAX_RETRIES, err.message);
    }
  }

  Logger.log("All %s attempts failed", CONFIG.MAX_RETRIES);
  return null;
}