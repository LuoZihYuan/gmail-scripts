function log_(msg) {
  var args = Array.prototype.slice.call(arguments);
  args[0] = "[" + CONFIG.ENV + "] " + msg;
  Logger.log.apply(Logger, args);
}

function processNewEmails() {
  const threads = getRecentInboxThreads_();

  for (const thread of threads) {
    try {
      const message = thread.getMessages()[thread.getMessageCount() - 1];
      const body = sanitize_(message.getPlainBody().substring(0, CONFIG.MAX_EMAIL_CHARS));
      const subject = sanitize_(message.getSubject());
      const from = message.getFrom();
      const date = message.getDate();
      const yearPrefix = "'" + Utilities.formatDate(date, Session.getScriptTimeZone(), "yy");

      const isRejection = resolveClassification_(subject, from, body);
      if (isRejection !== "rejection") continue;

      const roleCategory = resolveRole_(subject, from, body);
      const targetLabel = resolveLabel_(yearPrefix, roleCategory);
      targetLabel.addToThread(thread);
      thread.moveToArchive();

      log_("Filed: %s | Role: %s | Label: %s", subject, roleCategory || "unknown", targetLabel.getName());
    } catch (err) {
      log_("Error: %s — %s", thread.getFirstMessageSubject(), err.message);
    }
  }
}

// ── Classification ──────────────────────────────────────────

function resolveClassification_(subject, from, body) {
  const r1 = classifyRejection_(subject, from, body);
  const r2 = classifyRejection_(subject, from, body);
  if (!r1 || !r2) return "uncertain";
  if (r1.classification === r2.classification) return r1.classification;
  return classificationTiebreaker_(r1, r2, subject, from, body);
}

function classifyRejection_(subject, from, body) {
  return callGeminiApi_(`You are an email classifier. Determine whether this email is a job application rejection.

Respond with ONLY a valid JSON object — no markdown, no backticks, no extra text.

JSON schema:
{
  "classification": "rejection" or "not_rejection" or "uncertain",
  "reasoning": string
}

Rules:
- "rejection": clearly communicates the recipient was NOT selected / will NOT move forward.
- "not_rejection": clearly not a rejection (interview invites, confirmations, newsletters, promotions, receipts, etc.)
- "uncertain": cannot confidently determine.

Email:
Subject: ${subject}
From: ${from}
Body:
${body}`);
}

function classificationTiebreaker_(r1, r2, subject, from, body) {
  const result = callGeminiApi_(`You are a judge resolving a disagreement between two email classifiers.

Email:
Subject: ${subject}
From: ${from}
Body:
${body}

Classifier 1:
${JSON.stringify(r1, null, 2)}

Classifier 2:
${JSON.stringify(r2, null, 2)}

Determine the correct classification. Respond with ONLY a valid JSON object.

JSON schema:
{
  "classification": "rejection" or "not_rejection" or "uncertain",
  "reasoning": string
}`);

  if (!result) return "uncertain";
  log_("Classification tiebreaker: %s | %s", result.classification, result.reasoning);
  return result.classification;
}

// ── Role Classification ─────────────────────────────────────

function resolveRole_(subject, from, body) {
  const r1 = classifyRole_(subject, from, body);
  const r2 = classifyRole_(subject, from, body);
  if (!r1 || !r2) return null;

  const role1 = normalizeRole_(r1.roleCategory);
  const role2 = normalizeRole_(r2.roleCategory);
  if (role1 === role2) return role1;

  return roleTiebreaker_(r1, r2, subject, from, body);
}

function classifyRole_(subject, from, body) {
  return callGeminiApi_(`You are an email classifier. This email is a confirmed job rejection. Determine the role category.

Respond with ONLY a valid JSON object — no markdown, no backticks, no extra text.

JSON schema:
{
  "roleCategory": one of [${CONFIG.ROLE_LIST}] or "unknown",
  "reasoning": string
}

Rules:
- "SWE" = any software engineering role (backend, frontend, full-stack, data engineer, platform, DevOps, ML engineer, infrastructure, SRE, etc.)
- "SWE Intern" = any software engineering internship
- "PM" = product manager, program manager, TPM, or similar
- "PM Intern" = any PM internship
- "unknown" if not mentioned or doesn't fit. Do NOT guess.

Email:
Subject: ${subject}
From: ${from}
Body:
${body}`);
}

function roleTiebreaker_(r1, r2, subject, from, body) {
  const result = callGeminiApi_(`You are a judge resolving a disagreement between two role classifiers for a job rejection email.

Email:
Subject: ${subject}
From: ${from}
Body:
${body}

Classifier 1:
${JSON.stringify(r1, null, 2)}

Classifier 2:
${JSON.stringify(r2, null, 2)}

Determine the correct role. Respond with ONLY a valid JSON object.

JSON schema:
{
  "roleCategory": one of [${CONFIG.ROLE_LIST}] or "unknown",
  "reasoning": string
}`);

  if (!result) return null;
  log_("Role tiebreaker: %s | %s", result.roleCategory, result.reasoning);
  return normalizeRole_(result.roleCategory);
}

function normalizeRole_(role) {
  return role === "unknown" ? null : role;
}

// ── Gmail ───────────────────────────────────────────────────

function getRecentInboxThreads_() {
  const after = Math.floor((Date.now() - CONFIG.LOOKBACK_MINUTES * 1.5 * 60 * 1000) / 1000);
  return GmailApp.search("in:inbox after:" + after, 0, 50);
}

function resolveLabel_(yearPrefix, roleCategory) {
  const parentPath = yearPrefix + " Job Application";

  if (roleCategory && CONFIG.ROLE_CATEGORIES.includes(roleCategory)) {
    const label = GmailApp.getUserLabelByName(parentPath + "/" + yearPrefix + " " + roleCategory);
    if (label) return label;
  }

  return getOrCreateLabel_(parentPath);
}

function getOrCreateLabel_(name) {
  return GmailApp.getUserLabelByName(name) || GmailApp.createLabel(name);
}

// ── Triggers ────────────────────────────────────────────────

function installTrigger() {
  ScriptApp.getProjectTriggers()
    .filter(t => t.getHandlerFunction() === "processNewEmails")
    .forEach(t => ScriptApp.deleteTrigger(t));

  ScriptApp.newTrigger("processNewEmails").timeBased().everyMinutes(CONFIG.LOOKBACK_MINUTES).create();
  log_("Trigger installed.");
}

function uninstallTrigger() {
  ScriptApp.getProjectTriggers()
    .filter(t => t.getHandlerFunction() === "processNewEmails")
    .forEach(t => ScriptApp.deleteTrigger(t));
  log_("Trigger removed.");
}