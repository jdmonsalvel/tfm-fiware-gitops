#!/usr/bin/env bash
# Smoke test E2E del FIWARE Data Space
# Valida: [1] Trust Anchor health  [2] Registro del emisor en el TIL + JWT HS256
#         [3] Kong PEP (Tabla 26): 401 sin token, 401 firma inválida,
#             403 emisor fuera del TIL, 200 participante registrado
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
# Consumer con firma válida en Kong pero no registrado en el TIL
UNREG_ISS="${UNREG_ISS:-unregistered-participant-app}"
UNREG_SECRET="${UNREG_SECRET:-demo-unregistered-secret-tfm-2026}"

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

# http_is <código> <texto esperado en el cuerpo> <args de curl...>
http_is() {
  local want="$1" pattern="$2" out
  shift 2
  out=$(curl $CURL_OPTS -w '\n%{http_code}' "$@") || return 1
  [ "${out##*$'\n'}" = "$want" ] && grep -q -- "$pattern" <<<"${out%$'\n'*}"
}

# make_jwt <iss> <secret> — JWT HS256 con python3 (sin dependencias externas)
make_jwt() {
  python3 - "$1" "$2" <<'PYEOF'
import base64, hashlib, hmac, json, sys, time

def b64url(data):
    if isinstance(data, str):
        data = data.encode()
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

iss, secret = sys.argv[1], sys.argv[2]
header  = b64url(json.dumps({"alg":"HS256","typ":"JWT"}))
payload = b64url(json.dumps({"iss":iss,"exp":int(time.time())+3600}))
sig_input = f"{header}.{payload}".encode()
sig = hmac.new(secret.encode(), sig_input, hashlib.sha256).digest()
print(f"{header}.{payload}.{b64url(sig)}")
PYEOF
}

# El alta en el TIL va por port-forward: la API de escritura no se publica.
register_issuer() {
  local port=18080 pf rc=0
  kubectl port-forward -n trust-anchor svc/fiware-til-trusted-issuers-list "${port}:8080" >/dev/null 2>&1 &
  pf=$!
  sleep 3
  if ! curl -sf -o /dev/null "http://localhost:${port}/issuer/${JWT_ISS}"; then
    curl -sf -o /dev/null -X POST "http://localhost:${port}/issuer" \
      -H 'Content-Type: application/json' \
      -d "{\"did\":\"${JWT_ISS}\",\"credentials\":[]}" || rc=1
  fi
  kill "$pf" 2>/dev/null || true
  return "$rc"
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
check "TIL /issuer responde" \
  curl $CURL_OPTS -f "${TIL_URL}/issuer"

# ── [2] Emisor en el TIL + JWT HS256 ─────────────────────────────────────────
echo "[2/4] Participante registrado en TIL + tokens JWT HS256"
check "Emisor ${JWT_ISS} registrado en el TIL (idempotente)" register_issuer

TOKEN=$(make_jwt "${JWT_ISS}" "${JWT_SECRET}")
BAD_SIG_TOKEN=$(make_jwt "${JWT_ISS}" "firma-incorrecta")
UNREG_TOKEN=$(make_jwt "${UNREG_ISS}" "${UNREG_SECRET}")
check "JWT generados correctamente" test -n "${TOKEN}" -a -n "${BAD_SIG_TOKEN}" -a -n "${UNREG_TOKEN}"

# ── [3] Kong PEP — escenarios de la Tabla 26 ─────────────────────────────────
echo "[3/4] Kong PEP (Orion-LD)"
check "Sin header Authorization → 401 Unauthorized" \
  http_is 401 'Unauthorized' "${ORION_URL}/version"
check "Firma JWT inválida → 401 Invalid signature" \
  http_is 401 'Invalid signature' -H "Authorization: Bearer ${BAD_SIG_TOKEN}" "${ORION_URL}/version"
check "Emisor no registrado en TIL → 403 Forbidden" \
  http_is 403 'issuer not registered in Trusted Issuers List' -H "Authorization: Bearer ${UNREG_TOKEN}" "${ORION_URL}/version"
check "Participante registrado → 200 Orion-LD" \
  http_is 200 'orionld version' -H "Authorization: Bearer ${TOKEN}" "${ORION_URL}/version"

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
