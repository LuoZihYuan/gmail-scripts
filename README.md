# **Gmail Scripts**

Automate Gmail workflows with Google Apps Script and Gemini.

## **Prerequisites**

- [Node.js](https://nodejs.org/) (v20+)
- [pnpm](https://pnpm.io/)
- [clasp](https://github.com/google/clasp): `pnpm add -g @google/clasp`
- A [GCP project](https://console.cloud.google.com/) with a Desktop OAuth client
- `clasp login --creds <client_secret.json> --extra-scopes https://www.googleapis.com/auth/gmail.modify,https://www.googleapis.com/auth/gmail.labels,https://www.googleapis.com/auth/script.external_request,https://www.googleapis.com/auth/script.scriptapp`

### **Tab Completion (optional)**

Add to `~/.bashrc` or `~/.zshrc`:

```
source /path/to/gmail-scripts/completions.sh
```

## **Getting Started**

### **Setting Up an Existing Script**

```
make init s=rejection-sorter
make deploy s=rejection-sorter
```

### **Creating a New Script**

```
make new s=newsletter-sorter
make deploy s=newsletter-sorter
```

After creating a new script, add the following to its `appsscript.json` for remote execution:

```json
"executionApi": {
  "access": "ANYONE"
}
```

## **Publishing**

### **Via Git Push**

```
git push
```

Follow the prompts to set up prod projects and GitHub Secrets on first push. CI then publishes changed scripts to prod automatically on every push to `main`.

### **Via GitHub Actions**

Go to the [Actions tab](../../actions/workflows/deploy.yml), click "Run workflow", select a script, and follow the instructions.

## **Commands**

| Command | Description |
|---------|-------------|
| `make new s=<n>` | Scaffold a new script and create Apps Script project |
| `make init s=<n>` | Link an existing script to an Apps Script project |
| `make deploy s=<n>` | Build, push, and install trigger |
| `make publish s=<n>` | Build, push, version, and install trigger |
| `make open s=<n>` | Open in Apps Script editor |
| `make help` | Show available commands |