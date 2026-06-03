#!/usr/bin/env bash
# Smoke test E2E del FIWARE Data Space
# Valida: [1] Trust Anchor health  [2] Token OAuth2
#         [3] Orion-LD health      [4] NGSI-LD entities endpoint
set -euo pipefail

KEYROCK_URL="${KEYROCK_URL:-https://keyrock.lab-jdmonsalvel.com}"
ORION_URL="${ORION_URL:-https://orion.lab-jdmonsalvel.com}"
TIL_URL="${TIL_URL:-https://til.lab-jdmonsalvel.com}"
ADMIN_PASS="${KEYROCK_ADMIN_PASSWORD:-$(kubectl -n trust-anchor get secret keyrock-credentials -o jsonpath='{.data.adminPassword}' 2>/dev/null | base64 -d || echo 'adminTfm2026!')}"

# Resolver el NLB hostname via DNS de Cloudflare (1.1.1.1) para evitar caché local
NLB_HOSTNAME=$(dig +short keyrock.lab-jdmonsalvel.com @1.1.1.1 | grep "elb\|amazonaws" | head -1)
if [ -n "$NLB_HOSTNAME" ]; then
  NLB_IP=$(dig +short "$NLB_HOSTNAME" @1.1.1.1 | grep -E "^[0-9]" | head -1)
  if [ -n "$NLB_IP" ]; then
    CURL_RESOLVE="--resolve keyrock.lab-jdmonsalvel.com:443:${NLB_IP} \
      --resolve orion.lab-jdmonsalvel.com:443:${NLB_IP} \
      --resolve til.lab-jdmonsalvel.com:443:${NLB_IP}"
  fi
fi
CURL_OPTS="-sk --max-time 15 ${CURL_RESOLVE:-}"

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
  curl $CURL_OPTS "${KEYROCK_URL}/version"
check "TIL /v4/issuers responde" \
  curl $CURL_OPTS "${TIL_URL}/v4/issuers"

# ── [2] Token OAuth2 Keyrock ─────────────────────────────────────────────────
echo "[2/4] Token OAuth2 (Keyrock)"
TOKEN_JSON=$(curl $CURL_OPTS \
  -X POST "${KEYROCK_URL}/oauth2/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'Accept: application/json' \
  -u 'idm:idm' \
  -d "grant_type=password&username=admin&password=${ADMIN_PASS}&scope=openid" \
  2>/dev/null || echo "{}")

TOKEN=$(echo "${TOKEN_JSON}" | python3 -c \
  "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")

check "Token access_token obtenido" test -n "${TOKEN}"

# ── [3] Orion-LD health via Kong (requiere JWT) ──────────────────────────────
echo "[3/4] Provider health (Orion-LD via Kong PEP)"
check "Orion /version accesible via Kong con JWT" \
  bash -c "[ -n '${TOKEN}' ] && curl $CURL_OPTS -H \"Authorization: Bearer ${TOKEN}\" '${ORION_URL}/version'"

# ── [4] NGSI-LD entities ─────────────────────────────────────────────────────
echo "[4/4] NGSI-LD endpoint"
HTTP_CODE=$(curl $CURL_OPTS -o /dev/null -w "%{http_code}" --max-time 10 \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Link: <https://uri.etsi.org/ngsi-ld/v1/ngsi-ld-core-context.jsonld>; rel=\"http://www.w3.org/ns/json-ld#context\"; type=\"application/ld+json\"" \
  "${ORION_URL}/ngsi-ld/v1/entities?type=Test" 2>/dev/null || echo "000")

check "Orion NGSI-LD /entities via Kong (HTTP ${HTTP_CODE})" \
  bash -c "[ '${HTTP_CODE}' = '200' ] || [ '${HTTP_CODE}' = '204' ]"

# ── Resultado ────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════"
echo "  Resultado: ${pass} OK  /  ${fail} FAIL"
echo "════════════════════════════════════"
[[ ${fail} -eq 0 ]]
