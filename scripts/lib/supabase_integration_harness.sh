#!/usr/bin/env bash

if [[ -n "${DOGAREA_SUPABASE_HARNESS_LIB_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
DOGAREA_SUPABASE_HARNESS_LIB_LOADED=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${DOGAREA_SUPABASE_CONFIG:-$ROOT_DIR/supabaseConfig.xcconfig}"
CURL_TIMEOUT="${DOGAREA_SUPABASE_SMOKE_TIMEOUT:-20}"
CASE_FILTER="${DOGAREA_SUPABASE_CASE_FILTER:-}"
HARNESS_CASE_TOTAL=0
HARNESS_CASE_FAILED=0
HARNESS_LAST_LOGIN_STATUS=""
HARNESS_LAST_LOGIN_BODY=""
HARNESS_MEMBER_TOKEN=""
HARNESS_MEMBER_USER_ID=""
HARNESS_PROJECT_REF=""

resolve_xcconfig_value() {
  local key="$1"
  local file="$2"
  python3 - "$file" "$key" <<'PY'
import re
import sys

path, key = sys.argv[1], sys.argv[2]
variables = {}

with open(path, "r", encoding="utf-8") as f:
    for line in f:
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or "=" not in stripped:
            continue
        k, v = stripped.split("=", 1)
        variables[k.strip()] = v.strip().strip('"')

pattern = re.compile(r"\$\(([^)]+)\)")

def resolve(value: str, depth: int = 0) -> str:
    if depth > 16:
        return value
    def repl(match):
        name = match.group(1)
        replacement = variables.get(name, "")
        return resolve(replacement, depth + 1)
    return pattern.sub(repl, value)

print(resolve(variables.get(key, "")))
PY
}

harness_note() {
  printf '[SupabaseSmoke] %s\n' "$*"
}

harness_require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    harness_note "required file missing: $path"
    exit 1
  fi
}

harness_load_env() {
  harness_require_file "$CONFIG_FILE"

  SUPABASE_URL="${SUPABASE_URL:-$(resolve_xcconfig_value SUPABASE_URL "$CONFIG_FILE")}"
  SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$(resolve_xcconfig_value SUPABASE_ANON_KEY "$CONFIG_FILE")}"
  HARNESS_PROJECT_REF="${PROJECT_REF:-$(resolve_xcconfig_value PROJECT_REF "$CONFIG_FILE")}"

  if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
    harness_note "SUPABASE_URL / SUPABASE_ANON_KEY 값을 확인할 수 없습니다."
    exit 1
  fi

  if [[ -z "${DOGAREA_TEST_EMAIL:-}" || -z "${DOGAREA_TEST_PASSWORD:-}" ]]; then
    harness_note "DOGAREA_TEST_EMAIL / DOGAREA_TEST_PASSWORD 환경변수가 필요합니다."
    exit 1
  fi
}

harness_case_enabled() {
  local name="$1"
  if [[ -z "$CASE_FILTER" ]]; then
    return 0
  fi
  [[ "$name" =~ $CASE_FILTER ]]
}

harness_request_json() {
  local method="$1"
  local url="$2"
  local apikey="$3"
  local authorization="$4"
  local body="$5"
  local response=""
  local status="000"
  local payload=""
  local error_file
  error_file="$(mktemp)"

  if response="$(curl -sS --max-time "$CURL_TIMEOUT" -X "$method" "$url" \
    -H "Content-Type: application/json" \
    -H "apikey: $apikey" \
    -H "Authorization: $authorization" \
    --data "$body" \
    -w '\n%{http_code}' 2>"$error_file")"; then
    status="$(printf '%s' "$response" | tail -n 1)"
    payload="$(printf '%s' "$response" | sed '$d')"
  else
    payload="$(cat "$error_file")"
  fi

  rm -f "$error_file"
  printf '%s\n%s' "$status" "$payload"
}

harness_response_status() {
  printf '%s' "$1" | head -n 1
}

harness_response_body() {
  printf '%s' "$1" | tail -n +2
}

harness_json_field() {
  local json="$1"
  local path="$2"
  JSON_PAYLOAD="$json" python3 - "$path" <<'PY'
import json
import os
import sys

path = sys.argv[1].split('.')
raw = os.environ.get('JSON_PAYLOAD', '')
obj = json.loads(raw)
for key in path:
    if isinstance(obj, dict):
        obj = obj.get(key)
    else:
        obj = None
    if obj is None:
        print("")
        raise SystemExit(0)
if isinstance(obj, (str, int, float, bool)):
    print(obj)
else:
    print("")
PY
}

harness_first_pet_id() {
  local json="$1"
  JSON_PAYLOAD="$json" python3 - <<'PY'
import json
import os

raw = os.environ.get("JSON_PAYLOAD", "")
obj = json.loads(raw)
snapshot = obj.get("snapshot") if isinstance(obj, dict) else None
pets = snapshot.get("pets") if isinstance(snapshot, dict) else None
if isinstance(pets, list):
    for pet in pets:
        if isinstance(pet, dict) and isinstance(pet.get("id"), str) and pet["id"].strip():
            print(pet["id"].strip())
            raise SystemExit(0)
print("")
PY
}

harness_uuid() {
  python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
}

harness_snippet() {
  local text="$1"
  TEXT_PAYLOAD="$text" python3 - <<'PY'
import os
text = os.environ.get('TEXT_PAYLOAD', '').replace('\n', ' ')
print(text[:240])
PY
}

harness_expect_status() {
  local name="$1"
  local expected="$2"
  local response="$3"
  local detail="$4"
  if ! harness_case_enabled "$name"; then
    harness_note "SKIP $name filter=$CASE_FILTER"
    return 0
  fi
  HARNESS_CASE_TOTAL=$((HARNESS_CASE_TOTAL + 1))
  local actual body snippet
  actual="$(harness_response_status "$response")"
  body="$(harness_response_body "$response")"
  if [[ "$actual" == "$expected" ]]; then
    harness_note "PASS $name status=$actual $detail"
    return 0
  fi
  HARNESS_CASE_FAILED=$((HARNESS_CASE_FAILED + 1))
  snippet="$(harness_snippet "$body")"
  harness_note "FAIL $name expected=$expected actual=$actual $detail body=$snippet"
  return 0
}

harness_expect_not_status() {
  local name="$1"
  local rejected="$2"
  local response="$3"
  local detail="$4"
  if ! harness_case_enabled "$name"; then
    harness_note "SKIP $name filter=$CASE_FILTER"
    return 0
  fi
  HARNESS_CASE_TOTAL=$((HARNESS_CASE_TOTAL + 1))
  local actual body snippet
  actual="$(harness_response_status "$response")"
  body="$(harness_response_body "$response")"
  if [[ "$actual" != "$rejected" ]]; then
    harness_note "PASS $name status=$actual $detail"
    return 0
  fi
  HARNESS_CASE_FAILED=$((HARNESS_CASE_FAILED + 1))
  snippet="$(harness_snippet "$body")"
  harness_note "FAIL $name rejected=$rejected actual=$actual $detail body=$snippet"
  return 0
}

harness_login_member() {
  local response
  response="$(harness_request_json \
    "POST" \
    "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    "$SUPABASE_ANON_KEY" \
    "Bearer $SUPABASE_ANON_KEY" \
    "{\"email\":\"$DOGAREA_TEST_EMAIL\",\"password\":\"$DOGAREA_TEST_PASSWORD\"}")"
  HARNESS_LAST_LOGIN_STATUS="$(harness_response_status "$response")"
  HARNESS_LAST_LOGIN_BODY="$(harness_response_body "$response")"
  if [[ "$HARNESS_LAST_LOGIN_STATUS" != "200" ]]; then
    return 1
  fi
  HARNESS_MEMBER_TOKEN="$(harness_json_field "$HARNESS_LAST_LOGIN_BODY" "access_token")"
  HARNESS_MEMBER_USER_ID="$(harness_json_field "$HARNESS_LAST_LOGIN_BODY" "user.id")"
  [[ -n "$HARNESS_MEMBER_TOKEN" && -n "$HARNESS_MEMBER_USER_ID" ]]
}

harness_finish() {
  if (( HARNESS_CASE_FAILED > 0 )); then
    harness_note "FAIL summary total=$HARNESS_CASE_TOTAL failed=$HARNESS_CASE_FAILED"
    return 1
  fi
  harness_note "PASS summary total=$HARNESS_CASE_TOTAL failed=0 project_ref=${HARNESS_PROJECT_REF:-unknown}"
}
