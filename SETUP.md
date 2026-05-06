# SETUP.md — first-time provisioning runbook

You're about to provision the entire demo environment. Read the
pre-flight checklist below first, then work straight through Phase A,
Phase B, and Phase C. Don't skip the verification commands at the end
of each phase — they catch ~80% of the things that bite on stage.

---

## Pre-flight checklist (read this first — 60 seconds)

Before you start, confirm you have:

- [ ] An Azure subscription with **Owner** or **Contributor** role.
      `az role assignment list --assignee $(az account show --query user.name -o tsv) --scope /subscriptions/$(az account show --query id -o tsv)`
- [ ] A GitHub account with **Copilot Pro+** or **Copilot Enterprise**.
      Visit `github.com/settings/copilot` — must show "Copilot Pro+" or
      "Copilot Enterprise". Copilot Free does NOT include the Coding
      Agent.
- [ ] Permission to create a public repository under your GitHub user
      or org.
- [ ] About **90 minutes** of uninterrupted time (60 active + 30 wait).
- [ ] A laptop with **5 GB** free disk space.
- [ ] **Stable internet** — the SRE Agent provisioning step downloads
      ~500 MB.

If any are NO, stop and resolve before proceeding.

```
Total time:    ~90 minutes (60 active, 30 waiting on async Azure provisions)
Cleanup:       az group delete --name rg-agentic-loop-demo --yes (post-demo)
```

---

## Variables (collect once, reference everywhere below)

These are the only placeholder values in the document. Fill them in
this table. After Phase C, `infra/provision.sh` will write a
`.env.demo` file you can `source` so most of these are auto-populated.

| Name                       | What it is                                                      | Your value                  |
|----------------------------|-----------------------------------------------------------------|-----------------------------|
| `AZURE_SUBSCRIPTION_ID`    | The subscription you'll deploy into                              |                             |
| `AZURE_TENANT_ID`          | Tenant of that subscription                                      |                             |
| `AZURE_LOCATION`           | `eastus2` (default) — must support SRE Agent                     | `eastus2`                   |
| `NAME_SUFFIX`              | A short, globally-unique token (e.g., your initials + 4 digits) | `ptmsft01`                  |
| `GITHUB_OWNER`             | Your GitHub username or org                                      |                             |
| `GITHUB_REPO_NAME`         | Repository name                                                  | `agentic-loop-demo`         |
| `GITHUB_REPO`              | `${GITHUB_OWNER}/${GITHUB_REPO_NAME}`                            |                             |
| `RG_DEMO`                  | Demo resource group                                              | `rg-agentic-loop-demo`      |
| `RG_REHEARSAL`             | Rehearsal resource group                                         | `rg-agentic-loop-rehearsal` |
| `SRE_AGENT_NAME`           | Name you'll give the SRE Agent in Portal                         | `sre-aldemo`                |

---

## Phase totals

| Phase                                  | Active | Waiting | Total |
|----------------------------------------|--------|---------|-------|
| Phase A — Local machine                | 12 min | 3 min   | 15 min |
| Phase B — GitHub                       | 18 min | 2 min   | 20 min |
| Phase C — Azure CLI (C1–C5)            | 10 min | 5 min   | 15 min |
| Phase C — Azure SRE Agent (C6–C11)     | 25 min | 10 min  | 35 min |
| End-to-end verification                | 3 min  | 2 min   | 5 min  |
| **TOTAL**                              |        |         | **~90 min** |

---

# PHASE A — LOCAL MACHINE

> Goal: developer laptop has Node 20+, Azure CLI, GitHub CLI, gh-aw,
> Bicep, jq, repo cloned with `npm ci` complete, and authenticated to
> both Azure and GitHub.
>
> Estimated time: **15 min**.
> Exit condition: `bash scripts/verify-local.sh` prints `LOCAL ✓`.

## A1. Tool installation

**Where:** Local terminal.

**Estimated time:** 5 min.

**What you'll do:** Install Node 20+, Azure CLI, GitHub CLI, gh-aw
extension, Bicep, jq.

**Exact actions:**

```bash
# macOS — Homebrew is the default. Apple Silicon and Intel both work.
brew install node@20
brew link --overwrite --force node@20
brew install azure-cli
brew install gh
brew install jq

gh extension install github/gh-aw
gh extension upgrade github/gh-aw   # ensure ≥ v0.68.1 — earlier versions hang on Copilot CLI v1.0.22
az bicep install
```

> **gh-aw version note (researched May 2026):** v0.68.1 (April 10, 2026)
> includes a critical Copilot CLI reliability hotfix that pins the
> Copilot CLI back to v1.0.21. Earlier gh-aw releases will hang
> indefinitely or produce zero-byte output if Copilot CLI v1.0.22 is on
> the path. After install, run `gh aw version` and confirm ≥ 0.68.1.

**Expected result:**
- `node --version` → `v20.x.y`
- `az --version` → `azure-cli 2.60.0` or newer
- `gh --version` → `gh version 2.60.0` or newer
- `gh extension list` includes `gh-aw`
- `gh aw version` ≥ `0.68.1`
- `az bicep version` prints a Bicep version string

**Verification command:**

```bash
node --version && az --version | head -n1 && gh --version | head -n1 && gh extension list | grep gh-aw && az bicep version
```

**If this fails:**
- *Homebrew not installed* → install from
  `https://brew.sh` and re-run.
- *Node 20 link conflicts* (you have Node 18 already) → run
  `brew unlink node && brew link --overwrite --force node@20`.
- *gh-aw extension fails to install* → ensure `gh auth status` is
  authenticated first (see A5), then re-run.

---

## A2. Repository clone and dependency install

**Where:** Local terminal.

**Estimated time:** 2 min.

**What you'll do:** Clone the repo (or `cd` into it if you already
have it) and install Node dependencies in `src/`.

**Exact actions:**

```bash
cd ~/code  # or wherever you keep repos
git clone https://github.com/${GITHUB_REPO}.git agentic-loop-demo
cd agentic-loop-demo
( cd src && npm ci )
```

**Expected result:** `src/node_modules` directory exists; `package-lock.json` is unchanged.

**Verification command:**

```bash
ls src/node_modules/express/package.json
```

**If this fails:**
- *`npm ci` errors* → delete `src/node_modules` and `src/package-lock.json`,
  run `npm install` once to regenerate, commit the lock, then `npm ci`.

---

## A3. Local API verification

**Where:** Local terminal.

**Estimated time:** 2 min.

**What you'll do:** Run the test suite and start the server locally.
Confirm the seeded bug fires.

**Exact actions:**

```bash
( cd src && npm test ) || true   # 6 pass, 2 fail (the seeded bugs — expected pre-fix; the Coding Agent's PR makes both pass)
( cd src && npm start ) &
SERVER_PID=$!
sleep 1
curl -s -o /dev/null -w "GET /                   → %{http_code}\n" http://127.0.0.1:8080/
curl -s -o /dev/null -w "GET /products            → %{http_code}\n" http://127.0.0.1:8080/products
curl -s -o /dev/null -w "GET /products?cat=elec   → %{http_code}\n" http://127.0.0.1:8080/products?category=electronics
kill $SERVER_PID
```

**Expected result:**

```
GET /                   → 200
GET /products            → 500
GET /products?cat=elec   → 200
```

**Verification command:** the three lines above match exactly.

**If this fails:**
- *Port 8080 in use* → `PORT=8081 npm start` and adjust curl URLs.
- *All three return 500* → check `src/routes/products.js` was not edited
  to remove the seeded bug. Run `git diff src/routes/products.js`.

---

## A4. Authenticate Azure CLI

**Where:** Local terminal + browser.

**Estimated time:** 2 min.

**What you'll do:** Sign in to Azure and pin the right subscription.

**Exact actions:**

```bash
az login
# Browser opens. Sign in with the account that has the demo subscription.
az account list --output table
az account set --subscription "<AZURE_SUBSCRIPTION_ID>"
```

**Expected result:** `az account show --query name -o tsv` returns the
subscription you intend to use.

**Verification command:**

```bash
az account show --query "{user: user.name, sub: name, id: id}" -o table
```

**If this fails:**
- *Wrong account in browser* → `az logout` and `az login --tenant
  $AZURE_TENANT_ID`.
- *Account does not have access to the subscription* → ask your
  subscription owner to grant Contributor on the demo subscription.

---

## A5. Authenticate GitHub CLI

**Where:** Local terminal + browser.

**Estimated time:** 2 min.

**What you'll do:** Authenticate `gh` to GitHub.com.

**Exact actions:**

```bash
gh auth login
# Choose: GitHub.com → HTTPS → Login with a web browser → device flow
```

**Expected result:** `gh auth status` shows authenticated user.

**Verification command:**

```bash
gh auth status
```

**If this fails:**
- *Two-factor flow stalls* → `gh auth login --with-token < <(echo $TOKEN)`
  using a fine-grained PAT scoped to your user.

---

## A-VERIFY

**Where:** Local terminal.

**Estimated time:** 1 min.

**What you'll do:** Run the local verifier.

**Exact actions:**

```bash
bash scripts/verify-local.sh
```

**Expected result:** Final line is `LOCAL ✓` and exit code is 0.

**Verification command:** none beyond this script.

**If this fails:** the script prints which check failed with the exact
recovery command. Run it and re-run `verify-local.sh`.

---

# PHASE B — GITHUB

> Goal: a public repo named `agentic-loop-demo` exists, the codebase
> is pushed, secrets are set, the `production` environment requires a
> reviewer, Copilot Coding Agent and Code Review are enabled, branch
> protection is on `main`.
>
> Estimated time: **20 min**.
> Exit condition: `bash scripts/verify-github.sh` prints `GITHUB ✓`.

## B1. Create the repository

**Where:** Local terminal (preferred) OR `github.com → New repository`.

**Estimated time:** 1 min.

**What you'll do:** Create a public repo named `agentic-loop-demo`.

**Exact actions (CLI):**

```bash
gh repo create "${GITHUB_REPO}" --public \
  --description "GitHub Dev Days SF — The Agentic Developer Loop demo" \
  --confirm
```

**Or (UI):** `github.com → +` (top right) → New repository → Owner:
`${GITHUB_OWNER}` → Name: `agentic-loop-demo` → Public → Description as
above → Click `Create repository`.

**Expected result:** `gh repo view ${GITHUB_REPO}` works.

**Verification command:**

```bash
gh repo view "${GITHUB_REPO}" --json name,visibility --jq '"\(.name) [\(.visibility)]"'
```

**If this fails:**
- *Repo already exists under your account* — that is fine; skip B1.
- *403 forbidden* — check your token scope includes `repo`.

---

## B2. Push the codebase

**Where:** Local terminal.

**Estimated time:** 1 min.

**What you'll do:** Push the local repo to the new GitHub remote.

**Exact actions:**

```bash
git remote add origin "https://github.com/${GITHUB_REPO}.git" 2>/dev/null || \
  git remote set-url origin "https://github.com/${GITHUB_REPO}.git"
git add -A
git commit -m "chore: initial demo scaffold" || true
git push -u origin main
```

**Expected result:** `gh repo view ${GITHUB_REPO} --web` opens a repo
with the codebase visible.

**Verification command:**

```bash
gh api "repos/${GITHUB_REPO}/contents/src/server.js" --jq '.name'
# expect: server.js
```

**If this fails:** `git push` rejected on first push → run
`git pull --rebase origin main` then push again.

---

## B3. Generate the two fine-grained PATs

**Where:** GitHub.com (UI only — no CLI shortcut for fine-grained PATs).

**Estimated time:** 6 min.

**What you'll do:** Create **two** fine-grained PATs:

| Token name           | Used by                                                   | Required permissions                                                                                          |
|----------------------|-----------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| `COPILOT_GITHUB_TOKEN` | The cold-open `daily-status` agentic workflow (apply step) | Repo: Issues = R/W, Contents = R, Pull requests = R, Metadata = R. Account: **Copilot requests = R/W** (critical). |
| `GH_AW_AGENT_TOKEN`  | Assigning Issue #2 to the Copilot Coding Agent (stage-demo + manual fallback) | Repo: Actions = R/W, Contents = R/W, Issues = R/W, Pull requests = R/W, Metadata = R.                          |

> **Why two PATs?** Per gh-aw's published guidance
> (`https://github.github.com/gh-aw/reference/assign-to-copilot/`), the
> Copilot Coding Agent assignment API rejects GitHub App installation
> tokens and the workflow `GITHUB_TOKEN`. It requires a fine-grained
> PAT with the broader scope set above. The cold-open workflow's PAT
> is narrower — it never assigns to Copilot, it only files an issue.

**Exact actions (run twice — once per token):**

1. Avatar → **Settings** → **Developer settings** → **Personal access
   tokens** → **Fine-grained tokens** → **Generate new token**.
2. **Token name:** as in the table.
3. **Expiration:** 30 days (rotate after the event).
4. **Resource owner:** `${GITHUB_OWNER}`.
5. **Repository access:** *Only select repositories* → pick
   `agentic-loop-demo`.
6. Set the permissions per the table above.
7. Generate. Copy. Stash (you won't see them again).

**Expected result:** A token starting `github_pat_…` is on your
clipboard.

**Verification command:** none — GitHub does not expose PAT scopes via
public API.

**If this fails:**
- *Copilot requests permission not visible* → your account does not
  have a Copilot Pro+ or Enterprise license. Resolve at
  `github.com/settings/copilot`.

---

## B4. Configure repository secrets

**Where:** Local terminal (`gh secret set`).

**Estimated time:** 2 min.

**What you'll do:** Set the four repo secrets the workflows need.
`AZURE_*` come from Phase C; for now set `COPILOT_GITHUB_TOKEN` and
leave the others to be set after C3.

**Exact actions:**

```bash
gh secret set COPILOT_GITHUB_TOKEN --repo "${GITHUB_REPO}" --body "<paste-token-1-from-B3>"
gh secret set GH_AW_AGENT_TOKEN    --repo "${GITHUB_REPO}" --body "<paste-token-2-from-B3>"

# AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID are set
# automatically by infra/provision.sh in Phase C3.
```

**Expected result:**

```bash
gh secret list --repo "${GITHUB_REPO}" | grep -E "AZURE_CLIENT_ID|AZURE_TENANT_ID|AZURE_SUBSCRIPTION_ID|COPILOT_GITHUB_TOKEN"
# All four print after Phase C3 completes.
```

**Verification command:**

```bash
gh secret list --repo "${GITHUB_REPO}"
```

**If this fails:** `gh secret set` reports `403` → confirm you have
admin on the repo.

---

## B5. Configure the `production` environment

**Where:** Local terminal (`gh api`).

**Estimated time:** 2 min.

**What you'll do:** Create the `production` environment with a
required reviewer (this is the human gate audiences see on slide 5).

**Exact actions:**

```bash
USER_ID="$(gh api users/${GITHUB_OWNER} --jq .id)"
gh api -X PUT "repos/${GITHUB_REPO}/environments/production" \
  --input - <<EOF
{
  "wait_timer": 0,
  "reviewers": [{ "type": "User", "id": ${USER_ID} }],
  "deployment_branch_policy": null
}
EOF
```

**Expected result:** A `production` environment is visible at
`https://github.com/${GITHUB_REPO}/settings/environments` with one
required reviewer (you).

**Verification command:**

```bash
gh api "repos/${GITHUB_REPO}/environments/production" --jq .name
# expect: production
```

**If this fails:** `gh api` returns 422 → ensure `${USER_ID}` is a
number, not the string "null". Check `gh api users/${GITHUB_OWNER}`.

---

## B6. Enable Copilot Coding Agent at repo level

**Where:** GitHub.com → repo → **Settings** → **Copilot** → **Coding agent**.

**Estimated time:** 2 min.

**What you'll do:** Toggle the Coding Agent on for this repo.

**Exact actions:**

1. Open `https://github.com/${GITHUB_REPO}/settings/copilot/coding_agent`.
2. Click the **Enable Copilot coding agent for this repository** switch.
3. Confirm in the modal.

**Expected result:** The toggle is green; the screen shows "Coding
agent is enabled" with a list of trigger conditions.

**Verification command:** Go to `https://github.com/copilot/agents` and
confirm `agentic-loop-demo` is listed.

**If this fails:** The toggle is missing → your account license does
not include the Coding Agent. Check `github.com/settings/copilot`.

---

## B7. Enable Copilot Code Review at repo level

**Where:** GitHub.com → repo → **Settings** → **Copilot** → **Code review**.

**Estimated time:** 1 min.

**What you'll do:** Toggle Copilot Code Review on for this repo.

**Exact actions:**

1. Open `https://github.com/${GITHUB_REPO}/settings/copilot/code_review`.
2. Toggle **Enable Copilot code review on pull requests**.

**Expected result:** Toggle green. New PRs will get CCR comments.

**Verification command:** none beyond visual.

**If this fails:** see B6 — same license requirement.

---

## B8. Configure branch protection on `main`

**Where:** Local terminal (`gh api`).

**Estimated time:** 2 min.

**What you'll do:** Require PR reviews and status checks on `main`.

**Exact actions:**

```bash
gh api -X PUT "repos/${GITHUB_REPO}/branches/main/protection" \
  --input - <<'EOF'
{
  "required_status_checks": { "strict": true, "contexts": ["build-and-test"] },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

**Expected result:** `main` is protected; PRs require 1 approval and
the `build-and-test` job to pass before merge.

**Verification command:**

```bash
gh api "repos/${GITHUB_REPO}/branches/main/protection" --jq '.required_pull_request_reviews.required_approving_review_count'
# expect: 1
```

**If this fails:** 403 → require admin on the repo.

---

## B-VERIFY

**Exact actions:**

```bash
GITHUB_REPO="${GITHUB_REPO}" bash scripts/verify-github.sh
```

**Expected result:** `GITHUB ✓`.

**If this fails:** the script names which check failed and the
`SETUP.md` step that owns it.

---

# PHASE C — AZURE

> Goal: rg-agentic-loop-demo is provisioned in eastus2 with App Service
> + slots + App Insights + LAW + alert + action group; OIDC federated
> credentials are wired; SRE Agent is provisioned with the four RBAC
> roles, the KB upload, the IRP, and the GitHub MCP connector; the
> action group webhook points at the SRE Agent.
>
> Estimated time: **50 min**.
> Exit condition: `bash scripts/verify-azure.sh` prints `AZURE ✓`.

## Phase C in 6 lines (read first)

You will do six things in this phase. The detail below is exhaustive
because SRE Agent is a preview product and Portal flows shift; the
summary keeps you oriented.

```
C1.   Set subscription, register Microsoft.App RP                      (~2 min)
C2.   Register the four core RPs (Web, Insights, OperationalInsights,  (~2 min)
        ManagedIdentity)
C3.   Run infra/provision.sh for both rehearsal and demo groups        (~6 min)
C4.   Verify GitHub OIDC federated credentials                         (~1 min)
C5.   Verify App Service is reachable and AI is collecting             (~5 min)
C6.   Provision Azure SRE Agent in the Portal                          (~10 min)
C7.   Grant SRE Agent the four required RBAC roles                     (~4 min)
C8.   Upload Knowledge Base                                            (~3 min)
C9.   Configure the Incident Response Plan                             (~5 min)
C10.  Configure the GitHub MCP connector                               (~5 min)
C11.  Wire Action Group webhook → SRE Agent                            (~3 min)
                                                              Total:  ~50 min
```

> Note on environments: `deploy.yml` only declares `environment:
> production` (the human gate the audience sees on slide 5). There is
> no `staging` GitHub environment to create — staging-slot smoke
> testing happens without an environment gate.

## C1. Set subscription and verify region eligibility

**Where:** Local terminal.

**Estimated time:** 1 min.

**What you'll do:** Pin the active subscription and register the
`Microsoft.App` provider (the ARM RP that hosts the SRE Agent
resource type, `Microsoft.App/agents`). Confirm one of the supported
regions is in scope: **eastus2 / swedencentral / australiaeast**.

> **Note (researched May 2026):** Azure SRE Agent reached GA. The ARM
> resource type is `Microsoft.App/agents` (NOT `Microsoft.Sre/agents`,
> which was used during early preview). Current API version: `2026-01-01`.

**Exact actions:**

```bash
az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
state="$(az provider show --namespace Microsoft.App --query registrationState -o tsv 2>/dev/null || echo NotRegistered)"
[[ "$state" != "Registered" ]] && az provider register --namespace Microsoft.App --wait
```

**Expected result:** `Microsoft.App` is `Registered` (may take 1–2
min on first registration).

**Verification command:**

```bash
az provider show --namespace Microsoft.App --query registrationState -o tsv
# expect: Registered

# Confirm the SRE Agent resource type is exposed in your subscription:
az provider show --namespace Microsoft.App --query "resourceTypes[?resourceType=='agents'].locations | [0]" -o tsv
# expect: a list including eastus2 (and possibly swedencentral, australiaeast)
```

**If this fails:** *Microsoft.App is not a known provider* — extremely
unusual since `Microsoft.App` is also the RP for Azure Container Apps.
Verify your CLI account has access to the subscription. If
`agents` resource type is missing from the resourceTypes list, your
tenant may not yet be enabled for SRE Agent — check
`https://learn.microsoft.com/en-us/azure/sre-agent/overview`.

---

## C2. Register required resource providers

**Where:** Local terminal.

**Estimated time:** 2 min (most are pre-registered).

**Exact actions:**

```bash
for ns in Microsoft.Web Microsoft.Insights Microsoft.OperationalInsights Microsoft.ManagedIdentity; do
  state="$(az provider show --namespace $ns --query registrationState -o tsv 2>/dev/null || echo Unknown)"
  echo "$ns → $state"
  [[ "$state" != "Registered" ]] && az provider register --namespace $ns --wait
done
```

**Expected result:** every namespace prints `Registered`.

**Verification command:** the loop above; all four `Registered`.

**If this fails:** lacking permission → use Owner or have a sub admin
register on your behalf.

---

## C3. Run `infra/provision.sh`

**Where:** Local terminal.

**Estimated time:** 6 min (App Service plan + slots provision asynchronously).

**What you'll do:** Provision both resource groups (rehearsal first as
a smoke test, then demo). Provisioner writes `.env.rehearsal` and
`.env.demo`, configures OIDC, and pushes the three Azure secrets to
GitHub.

**Exact actions:**

```bash
GITHUB_REPO="${GITHUB_REPO}" \
NAME_SUFFIX="${NAME_SUFFIX}" \
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}" \
  bash infra/provision.sh --target rehearsal

GITHUB_REPO="${GITHUB_REPO}" \
NAME_SUFFIX="${NAME_SUFFIX}" \
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}" \
  bash infra/provision.sh --target demo
```

**Expected result:** Two resource groups exist with App Service +
slots + App Insights + LAW + alert + action group. `.env.demo` and
`.env.rehearsal` files are written. Three GitHub secrets are pushed.

**Verification command:**

```bash
test -f .env.demo && echo "OK: .env.demo present"
az group show --name rg-agentic-loop-demo --query location -o tsv
gh secret list --repo "${GITHUB_REPO}" | grep -E "AZURE_(CLIENT|TENANT|SUBSCRIPTION)_ID"
```

**If this fails:**
- *Bicep deployment errors* → re-run; resources are idempotent.
- *Federated credential creation fails* → your Azure AD tenant requires
  admin consent for application creation. Ask a tenant admin to run
  `az ad app create --display-name aldemo-deployer-${NAME_SUFFIX}`
  once, then re-run `provision.sh`.

---

## C4. Verify GitHub OIDC federated credentials

**Where:** Local terminal.

**Estimated time:** 1 min.

**Exact actions:**

```bash
APP_ID="$(az ad app list --display-name "aldemo-deployer-${NAME_SUFFIX}" --query '[0].appId' -o tsv)"
az ad app federated-credential list --id "$APP_ID" --query "[].{name:name, subject:subject}" -o table
```

**Expected result:** Three rows: `github-main`, `github-pull_request`,
`github-production`.

**Verification command:** the table above.

**If this fails:** re-run `provision.sh`; the federation create step
is idempotent.

---

## C5. Verify App Service is reachable and Application Insights is collecting

**Where:** Local terminal.

**Estimated time:** 5 min (you also push the first deploy here).

**Exact actions:**

```bash
# Push main → triggers .github/workflows/deploy.yml → deploys to staging
# → smoke test → human approval → swap to production.
git push origin main
gh run watch --repo "${GITHUB_REPO}"

source .env.demo
curl -s -o /dev/null -w "%{http_code}\n" "${APP_URL}/"
# expect: 200
```

**Expected result:** Production slot is serving the FIXED code (you'll
land on this in Phase 1 of the demo flow). `/` returns 200.

**Verification command:**

```bash
bash scripts/verify-deploy.sh
```

**If this fails:** open the failed Action run in GitHub; the most
common cause is a missing or stale `AZURE_*` secret. Re-run `provision.sh`.

---

## C6. Provision Azure SRE Agent (Portal walkthrough)

**Where:** Azure Portal — `https://portal.azure.com`.

**Estimated time:** 10 min.

**What you'll do:** Create the SRE Agent resource via the Portal.
Preview product; CLI/ARM coverage is partial, so we use the Portal.

**Exact actions:**

1. **Open the Portal** → top search bar → type `SRE Agent` → click
   **Azure SRE Agent** under *Services*. The screen shows the SRE Agent
   blade with an **+ Create** button at the top-left.

2. Click **+ Create**. The **Create Azure SRE Agent** form appears with
   tabs across the top: **Basics**, **Networking**, **Tags**, **Review + create**.

3. **Basics tab — fill in tab order:**
   - **Subscription:** the same subscription as the demo resource group.
   - **Resource group:** `rg-agentic-loop-demo`.
   - **Region:** *eastus2*. **⚠️ This must be eastus2.** SRE Agent is
     not available in other regions yet (or only `swedencentral` /
     `australiaeast`). The demo uses eastus2.
   - **SRE Agent name:** `${SRE_AGENT_NAME}` (e.g., `sre-aldemo`).
   - **Pricing tier:** *Standard* (the only option in preview).
   - Click **Next: Networking**.

4. **Networking tab:** leave defaults (public network access, no VNet
   integration). Click **Next: Tags**.

5. **Tags tab:** add `workload=agentic-loop-demo` and `event=ghdd-sf-2026`.
   Click **Next: Review + create**.

6. **Review + create tab:** confirm Region = eastus2 and Resource group
   = rg-agentic-loop-demo. Click **Create**.

7. **Wait** ~3–5 min for deployment. The notification panel (top
   right, bell icon) shows progress. When complete, click **Go to
   resource**. You'll land on the SRE Agent overview blade.

8. **Capture the managed identity Principal ID:** on the SRE Agent
   overview, click **Identity** in the left nav. Confirm
   *System assigned = On*. Copy the **Object (principal) ID** GUID. You
   need it in C7.

**Expected result:** The SRE Agent resource exists in
`rg-agentic-loop-demo`, status *Succeeded*, with a system-assigned
managed identity.

**Verification command:**

```bash
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/rg-agentic-loop-demo/providers/Microsoft.App/agents?api-version=2026-01-01" \
  | jq '.value[] | {name: .name, location: .location, principalId: .identity.principalId}'
```

**If this fails:** *Region picker doesn't show eastus2* → your subscription is
not approved for the preview yet. See C1.

---

## C7. Grant SRE Agent the four required RBAC roles

**Where:** Local terminal (`az role assignment create`).

**Estimated time:** 4 min (5-min role propagation delay).

**What you'll do:** Assign Reader, Monitoring Reader, Log Analytics
Reader, and SRE Agent Administrator (preview role) to the SRE Agent's
managed identity at the resource-group scope.

**Exact actions:**

```bash
SRE_PRINCIPAL="<paste-Object-ID-from-C6.8>"
SCOPE="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/rg-agentic-loop-demo"

for role in "Reader" "Monitoring Reader" "Log Analytics Reader"; do
  az role assignment create --assignee "$SRE_PRINCIPAL" --role "$role" --scope "$SCOPE"
done

# The "SRE Agent Administrator" role is preview-only. The role name in
# your tenant may differ slightly — list candidates first.
az role definition list --query "[?contains(roleName, 'SRE')].roleName" -o tsv
# Pick the matching name and assign:
az role assignment create --assignee "$SRE_PRINCIPAL" --role "SRE Agent Administrator" --scope "$SCOPE"
```

**Expected result:** Four role assignments. RBAC propagation can take
up to 5 min.

**Verification command:**

```bash
az role assignment list --assignee "$SRE_PRINCIPAL" --all --query "[].roleDefinitionName" -o tsv
```

**If this fails:**
- *Role 'SRE Agent Administrator' does not exist* → the preview is not
  yet exposing this role in your tenant. Skip it; the other three are
  the load-bearing ones for read-and-investigate.

---

## C8. Upload Knowledge Base content

**Where:** Azure Portal → SRE Agent → **Knowledge base**.

**Estimated time:** 3 min.

**What you'll do:** Upload `docs/http-5xx-runbook.md` so the SRE Agent
can ground its investigation.

**Exact actions:**

1. SRE Agent overview → **Knowledge base** in left nav.
2. Click **+ Upload**.
3. **File type:** Markdown. Select `docs/http-5xx-runbook.md` from your
   local repo.
4. **Title:** *Catalog API HTTP 5xx on /products*.
5. **Tags:** `service:catalog-api`, `signal:5xx`.
6. Click **Upload**. Wait ~30 sec for ingestion.

**Expected result:** The runbook appears in the KB list with status
*Indexed*.

**Verification command:**

```bash
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/rg-agentic-loop-demo/providers/Microsoft.App/agents/${SRE_AGENT_NAME}/knowledgebase?api-version=2026-01-01" \
  | jq '.value | length'
# expect: ≥ 1
```

**If this fails:** the upload sits in *Pending* > 2 min → re-upload.
Common cause: file > 5 MB. Our runbook is < 10 KB so this is unlikely.

---

## C9. Configure the Incident Response Plan

**Where:** Azure Portal → SRE Agent → **Incident response plans**.

**Estimated time:** 5 min.

**What you'll do:** Create a plan that fires for our 5xx alert and runs
the SRE Agent in **Review** mode (not Autonomous, for the demo).

**Exact actions:**

1. SRE Agent overview → **Incident response plans** → **+ New plan**.
2. **Name:** `catalog-api-5xx`.
3. **Filter — Source:** Azure Monitor.
4. **Filter — Resource type:** `Microsoft.Web/sites`.
5. **Filter — Severity:** Sev 2.
6. **Response mode:** *Review* (the SRE Agent prepares the response;
   a human approves before any write to GitHub fires). For
   live stage, this is what the audience sees on slide 5 — the human
   gate.
7. **Custom agent:** *Default* (`incident-handler`).
8. **Linked Knowledge Base:** select the runbook uploaded in C8.
9. Click **Save**.

**Expected result:** Plan appears in the list with *State = Enabled*.

**Verification command:**

```bash
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/rg-agentic-loop-demo/providers/Microsoft.App/agents/${SRE_AGENT_NAME}/incidentResponsePlans?api-version=2026-01-01" \
  | jq '.value[].name'
```

**If this fails:** Plan creation form rejects the filter — verify your
metric alert from `infra/main.bicep` is severity 2 and resource type
`Microsoft.Web/sites`. Adjust either the alert or the filter.

---

## C10. Configure the GitHub MCP connector

**Where:** Azure Portal → SRE Agent → **Settings** → **MCP servers**.

**Estimated time:** 5 min.

**What you'll do:** Connect the SRE Agent to GitHub's MCP server so it
can call `file_issue` to close the loop. **Important:** generate a
**SEPARATE** PAT for this — it is *not* `COPILOT_GITHUB_TOKEN`.

**Exact actions:**

1. **Generate a new fine-grained PAT** (`github.com → Settings →
   Developer settings → Personal access tokens → Fine-grained tokens →
   Generate new token`):
   - Name: `agentic-loop-demo / sre-agent-mcp`.
   - Repository access: only `agentic-loop-demo`.
   - Repository permissions: **Issues = Read & Write**, Contents = Read,
     Pull requests = Read, Metadata = Read.
   - Expiration: 30 days.
   - Generate. Copy.
2. Back in the Portal: SRE Agent → Settings → **MCP servers** →
   **+ Add server**.
3. **Type:** HTTP.
4. **Name:** `github-mcp`.
5. **URL:** `https://api.githubcopilot.com/mcp/`.
6. **Authentication:** GitHub PAT → paste the token from step 1.
7. Click **Test connection** → expect *Success*.
8. Click **Save**.
9. Confirm the available tools list shows `file_issue` (and
   `add_comment`, `update_issue` etc.).

**Expected result:** The MCP server appears in the list with status
*Connected*; `file_issue` is in the tool list.

**Verification command (best-effort — preview API):**

```bash
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/rg-agentic-loop-demo/providers/Microsoft.App/agents/${SRE_AGENT_NAME}/mcpServers?api-version=2026-01-01" \
  | jq '.value[] | {name: .name, status: .properties.status}'
```

**If this fails:**
- *Test connection returns 401* → PAT scope wrong; regenerate with
  `Issues: Read & Write`.
- *Test connection returns 403 from MCP server* → check the URL is the
  current Copilot MCP endpoint (the host moves occasionally — verify
  in the GitHub Copilot docs).

---

## C11. Wire Action Group webhook → SRE Agent

**Where:** Local terminal + Portal.

**Estimated time:** 3 min.

**What you'll do:** Replace the placeholder webhook in the Bicep-
provisioned action group with the SRE Agent incoming webhook URL.

**Exact actions:**

```bash
source .env.demo

# Fetch the SRE Agent incoming webhook URL (preview API).
SRE_HOOK="$(az rest --method GET \
  --uri "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/rg-agentic-loop-demo/providers/Microsoft.App/agents/${SRE_AGENT_NAME}/listIncomingWebhook?api-version=2026-01-01" \
  | jq -r '.url')"

echo "SRE Agent webhook URL: ${SRE_HOOK}"

az monitor action-group update \
  --resource-group "${AZURE_RG}" \
  --name "${ACTION_GROUP_NAME}" \
  --add-action webhook sre-agent-webhook "${SRE_HOOK}" \
  --remove-action sre-agent-webhook 2>/dev/null || true

# Re-add cleanly.
az monitor action-group update \
  --resource-group "${AZURE_RG}" \
  --name "${ACTION_GROUP_NAME}" \
  --action webhook sre-agent-webhook "${SRE_HOOK}" \
  --short-name aldemoSre
```

**Expected result:** Action group's webhook receiver `sre-agent-webhook`
points at the SRE Agent URL.

**Verification command:**

```bash
az monitor action-group show \
  --resource-group "${AZURE_RG}" \
  --name "${ACTION_GROUP_NAME}" \
  --query "webhookReceivers[0].serviceUri" -o tsv
```

**If this fails:** *listIncomingWebhook* returns 404 → the API version
moved; check the SRE Agent Portal blade *Settings → Incoming webhooks*
and copy the URL by hand. Then run the `az monitor action-group update`
command.

---

## C-VERIFY

**Exact actions:**

```bash
bash scripts/verify-azure.sh
```

**Expected result:** `AZURE ✓`.

---

# END-TO-END VERIFICATION

**Where:** Local terminal.

**Estimated time:** 5 min.

**Exact actions:**

```bash
bash scripts/verify-end-to-end.sh
```

**Expected result:** Final line is `END-TO-END ✓`. Six steps pass:
/products returns 200, daily-status produces an issue, trigger-failure
produces 500s, alert fires, SRE Agent files an issue. Cleanup runs
automatically.

**Verification command:** the script's exit code.

**If this fails:** the script names which step failed and the most
likely cause.

---

# Cleanup (post-demo full teardown)

```bash
az group delete --name rg-agentic-loop-demo      --yes --no-wait
az group delete --name rg-agentic-loop-rehearsal --yes --no-wait
az group delete --name rg-agentic-loop-demo-backup --yes --no-wait 2>/dev/null || true
gh repo delete "${GITHUB_REPO}" --yes 2>/dev/null || true
```
