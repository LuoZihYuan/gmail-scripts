const REDACT_PATTERNS = [
  { regex: /\b\d{3}-\d{2}-\d{4}\b/g, label: "[SSN]" },
  { regex: /\b\d{9}\b/g, label: "[SSN]" },
  { regex: /\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g, label: "[CARD]" },
  { regex: /\b(api[_-]?key|apikey|secret[_-]?key|access[_-]?token|auth[_-]?token|bearer)\s*[:=]\s*\S+/gi, label: "[API_KEY]" },
  { regex: /\b(password|passwd|pwd)\s*[:=]\s*\S+/gi, label: "[PASSWORD]" },
  { regex: /\b(temporary password|one-time password|otp)\s*[:=]?\s*\S+/gi, label: "[PASSWORD]" },
];

function sanitize_(text) {
  let result = text;
  for (const { regex, label } of REDACT_PATTERNS) {
    result = result.replace(regex, label);
  }
  return result;
}