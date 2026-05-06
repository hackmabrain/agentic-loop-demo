#!/usr/bin/env bash
# Smoke-tests a deployed Catalog API.
#
# Used by .github/workflows/deploy.yml after the slot swap and by Pavan
# at any point to confirm that the FIXED code is live in production.
#
# Exit codes: 0 on success, 1 on any failure.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

TARGET="demo"
[[ "${1:-}" == "--target" ]] && TARGET="${2:-demo}"

ENV_FILE="${REPO_ROOT}/.env.${TARGET}"
[[ -f "${ENV_FILE}" ]] || { echo "ERROR: ${ENV_FILE} not found."; exit 1; }
# shellcheck source=/dev/null
source "${ENV_FILE}"

PASS=0
FAIL=0

check() {
  local label="$1" url="$2" expected="$3"
  local actual
  actual="$(curl -s -o /dev/null -w "%{http_code}" "$url")"
  if [[ "$actual" == "$expected" ]]; then
    echo "[ ✓ ] ${label} (HTTP ${actual})"
    PASS=$((PASS + 1))
  else
    echo "[ ✗ ] ${label} — expected ${expected}, got ${actual}"
    FAIL=$((FAIL + 1))
  fi
}

echo "Smoke-testing ${APP_URL} …"
check "GET / returns 200"                         "${APP_URL}/"                              "200"
check "GET /products returns 200 (post-fix)"      "${APP_URL}/products"                      "200"
check "GET /products?category=electronics 200"    "${APP_URL}/products?category=electronics" "200"
check "GET /products/p-001 returns 200"           "${APP_URL}/products/p-001"                "200"
check "GET /products/does-not-exist returns 404"  "${APP_URL}/products/does-not-exist"       "404"

echo
echo "PASS=${PASS} FAIL=${FAIL}"
[[ "${FAIL}" -eq 0 ]] && echo "DEPLOY ✓" || { echo "DEPLOY ✗"; exit 1; }
