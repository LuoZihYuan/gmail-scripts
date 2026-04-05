# **Rejection Sorter**

Classifies job rejection emails using the Gemini API, labels them, and archives from inbox.

## **How It Works**

Runs every 5 minutes via a time-driven trigger. For each recent inbox email:

1. **Classification** — Two Gemini calls determine if the email is a rejection. If they disagree, a tiebreaker call reviews both responses with their reasoning.
2. **Role detection** — Same dual-call + tiebreaker approach to categorize the role.
3. **Label + archive** — Matched rejections are labeled and archived. Everything else is left untouched.

## **Label Structure**

```
'<yy> Job Application
├── '<yy> PM
├── '<yy> PM Intern
├── '<yy> SWE
└── '<yy> SWE Intern
```

Falls back to the parent `'<yy> Job Application` if the role can't be determined.

## **Role Mapping**

| Category | Matches |
|----------|---------|
| SWE | Backend, frontend, full-stack, data engineer, platform, DevOps, ML engineer, infrastructure, SRE |
| SWE Intern | Any software engineering internship |
| PM | Product manager, program manager, TPM |
| PM Intern | Any PM internship |

## **Privacy**

Email content is sanitized before being sent to the Gemini API. Redacted patterns: SSNs, credit card numbers, API keys, passwords.

## **Configuration**

| Setting | File | Default |
|---------|------|---------|
| Gemini model | `config.js` | `gemini-2.0-flash` |
| Check interval | `config.js` | 5 minutes |
| Role categories | `config.js` | PM, PM Intern, SWE, SWE Intern |
| Max retries | `config.js` | 3 |
| Time zone | `appsscript.json` | America/Los_Angeles |