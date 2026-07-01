#!/usr/bin/env bash
# Smoke test E2E del FIWARE Data Space
# Valida: [1] Trust Anchor health  [2] JWT HS256 generado
#         [3] Orion-LD via Kong PEP (JWT válido → 200)
#         [4] NGSI-LD entities endpoint
#
# Flujo iSHARE implementado: el participante presenta un JWT firmado con
# HS256 cuyo 'iss' está registrado en el TIL. Kong valida la firma y
# consulta el TIL antes de reenviar la petición a Orion-LD.
set -euo pipefail

KEYROCK_URL="${KEYROCK_URL:-https://keyrock.lab-jdmonsalvel.com}"
ORION_URL="${ORION_URL:-https://orion.lab-jdmonsalvel.com}"
TIL_URL="${TIL_URL:-https://til.lab-jdmonsalvel.com}"

# Credenciales del participante registrado en Kong y en TIL
JWT_ISS="${JWT_ISS:-fiware-dataspace-provider-app}"
JWT_SECRET="${JWT_SECRET:-demo-jwt-secret-tfm-2026}"

# Resolver el NLB hostname via DNS de Cloudflare (1.1.1.1) para evitar caché local
NLB_HOSTNAME=$(dig +short keyrock.lab-jdmonsalvel.com @1.1.1.1 | grep "elb\|amazonaws" | head -1 || true)
if [ -n "$NLB_HOSTNAME" ]; then
  NLB_IP=$(dig +short "$NLB_HOSTNAME" @1.1.1.1 | grep -E "^[0-9]" | head -1 || true)
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
echo "  ISS     : ${JWT_ISS}"
echo ""

# ── [1] Trust Anchor health ──────────────────────────────────────────────────
echo "[1/4] Trust Anchor health"
check "Keyrock /version responde" \
  curl $CURL_OPTS "${KEYROCK_URL}/version"
check "TIL /v4/issuers responde" \
  curl $CURL_OPTS "${TIL_URL}/v4/issuers"

# ── [2] JWT HS256 ────────────────────────────────────────────────────────────
echo "[2/4] Token JWT HS256 (participante registrado en TIL)"

# Generar JWT con python3 (sin dependencias externas)
TOKEN=$(python3 - <<PYEOF
import base64, hashlib, hmac, json, time

def b64url(data):
    if isinstance(data, str):
        data = data.encode()
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

header  = b64url(json.dumps({"alg":"HS256","typ":"JWT"}))
payload = b64url(json.dumps({"iss":"${JWT_ISS}","exp":int(time.time())+3600}))
sig_input = f"{header}.{payload}".encode()
sig = hmac.new("${JWT_SECRET}".encode(), sig_input, hashlib.sha256).digest()
print(f"{header}.{payload}.{b64url(sig)}")
PYEOF
)

check "JWT generado correctamente" test -n "${TOKEN}"

# ── [3] Orion-LD health via Kong (JWT válido → 200) ─────────────────────────
echo "[3/4] Provider health (Orion-LD via Kong PEP)"
check "Orion /version accesible via Kong con JWT válido" \
  bash -c "curl $CURL_OPTS -H 'Authorization: Bearer ${TOKEN}' '${ORION_URL}/version' | grep -q 'orionld version'"

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
