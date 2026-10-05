## Title

`Catalog API returning 500s on /products`

## Body (paste verbatim into the new issue)

```
The Catalog API is returning HTTP 500 on GET /products with no query string.

Reproduction:

  curl -i https://<APP_URL>/products
  HTTP/1.1 500 Internal Server Error

  curl -i https://<APP_URL>/products?category=electronics
  HTTP/1.1 200 OK

Expected:
  GET /products with no query string should return the full catalog with
  HTTP 200. The bug appears to be a missing nil-check on req.query.category.

Acceptance criteria:
  - GET /products → 200, full list
  - GET /products?category=electronics → 200, electronics only
  - GET /products?category=does-not-exist → 400 (input validation)
  - At least one regression test that fails today and passes after the fix.

Assignee: @copilot (please pick this up)
Priority: high — visible from /products on production
```

## How to file it on stage

1. Click `New issue` in the Issues tab.
2. Paste the title from above.
3. Paste the body from above (replace `<APP_URL>` with the demo URL).
4. In the right-hand sidebar, click **Assignees** → type `Copilot` in
   the search → pick the **Copilot** bot result (it has the GitHub
   Copilot icon next to the name; the underlying account is
   `copilot-swe-agent`).
5. Click `Submit new issue`.
6. The Coding Agent reacts with 👀 within a few seconds, then starts an
   agent session and opens a draft PR on a `copilot/fix-products-500`
   branch within ~30–90 sec.

**If Copilot doesn't appear in the assignee search:**
- Confirm the repo has Copilot Coding Agent enabled (SETUP step B6).
- Confirm your GitHub account has Copilot Pro+ or Enterprise.
- The bot is `copilot-swe-agent`; some search boxes match on the
  display name, others on the login. Try both.

## Why this issue, this wording, this audience

- The reproduction is two `curl` commands the audience can imagine
  running themselves.
- The acceptance criteria are explicit. Coding Agent does best with
  bounded asks — "fix the bug" is too vague; "make these three calls
  return these three statuses" is exactly enough.
- Setting **Assignee = Copilot** is the literal mechanism that triggers
  the Coding Agent. It is not a chat command. It is a normal GitHub
  affordance — that is the point of the slide.
