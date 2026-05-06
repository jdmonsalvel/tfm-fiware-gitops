#!/usr/bin/env bash
# Smoke test E2E del FIWARE Data Space
# Valida: [1] Trust Anchor health  [2] Token OAuth2
#         [3] Orion-LD health      [4] NGSI-LD entities endpoint
set -euo pipefail

KEYROCK_URL="${KEYROCK_URL:-http://keyrock.127.0.0.1.nip.io}"
ORION_URL="${ORION_URL:-http://orion.127.0.0.1.nip.io}"
TIL_URL="${TIL_URL:-http://til.127.0.0.1.nip.io}"
ADMIN_PASS="${KEYROCK_ADMIN_PASSWORD:-adminTfm2026!}"

pass=0; fail=0

check() {
  local name="$1"; shift
  if "$@" &>/dev/null; then
    echo "  [OK] ${name}"
    ((pass++)) || true
  else
    echo "  [FAIL] ${name}" >&2
    ((fail++)) || true
  fi
}

echo "═══════════════════════════════════════════════════════"
echo "  FIWARE Data Space — Smoke Test E2E"
echo "═══════════════════════════════════════════════════════"
echo "  Keyrock : ${KEYROCK_URL}"
echo "  Orion   : ${ORION_URL}"
echo "  TIL     : ${TIL_URL}"
echo ""

# ── [1] Trust Anchor health ──────────────────────────────────────────────────
echo "[1/4] Trust Anchor health"
check "Keyrock /version responde" \
  curl -sf --max-time 10 "${KEYROCK_URL}/version"
check "TIL /v4/issuers responde" \
  curl -sf --max-time 10 "${TIL_URL}/v4/issuers"

# ── [2] Token OAuth2 Keyrock ─────────────────────────────────────────────────
echo "[2/4] Token OAuth2 (Keyrock)"
TOKEN_JSON=$(curl -sf --max-time 15 \
  -X POST "${KEYROCK_URL}/oauth2/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'Accept: application/json' \
  -u 'idm:idm' \
  -d "grant_type=password&username=admin&password=${ADMIN_PASS}&scope=openid" \
  2>/dev/null || echo "{}")

TOKEN=$(echo "${TOKEN_JSON}" | python3 -c \
  "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")

check "Token access_token obtenido" test -n "${TOKEN}"

# ── [3] Orion-LD health ──────────────────────────────────────────────────────
echo "[3/4] Provider health (Orion-LD)"
check "Orion /version responde" \
  curl -sf --max-time 10 "${ORION_URL}/version"

# ── [4] NGSI-LD entities ─────────────────────────────────────────────────────
echo "[4/4] NGSI-LD endpoint"
HTTP_CODE=$(curl -so /dev/null -w "%{http_code}" --max-time 10 \
  -H "Link: <https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld>; rel=\"http://www.w3.org/ns/json-ld#context\"; type=\"application/ld+json\"" \
  "${ORION_URL}/ngsi-ld/v1/entities" 2>/dev/null || echo "000")

check "Orion NGSI-LD /entities (HTTP ${HTTP_CODE})" \
  bash -c "[ '${HTTP_CODE}' = '200' ] || [ '${HTTP_CODE}' = '204' ]"

# ── Resultado ────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════"
echo "  Resultado: ${pass} OK  /  ${fail} FAIL"
echo "════════════════════════════════════"
[[ ${fail} -eq 0 ]]
