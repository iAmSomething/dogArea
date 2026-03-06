#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${DOGAREA_SUPABASE_CONFIG:-$ROOT_DIR/supabaseConfig.xcconfig}"
ITERATIONS="${DOGAREA_AUTH_SMOKE_ITERATIONS:-3}"

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

raw = variables.get(key, "")
print(resolve(raw))
PY
}

if [[ -z "${DOGAREA_TEST_EMAIL:-}" || -z "${DOGAREA_TEST_PASSWORD:-}" ]]; then
  echo "[AuthSmoke] DOGAREA_TEST_EMAIL / DOGAREA_TEST_PASSWORD 환경변수가 필요합니다."
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[AuthSmoke] Supabase config 파일을 찾을 수 없습니다: $CONFIG_FILE"
  exit 1
fi

SUPABASE_URL="${SUPABASE_URL:-$(resolve_xcconfig_value SUPABASE_URL "$CONFIG_FILE")}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$(resolve_xcconfig_value SUPABASE_ANON_KEY "$CONFIG_FILE")}"

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "[AuthSmoke] SUPABASE_URL / SUPABASE_ANON_KEY 값을 확인할 수 없습니다."
  exit 1
fi

extract_json_field() {
  local json="$1"
  local path="$2"
  JSON_PAYLOAD="$json" python3 - "$path" <<'PY'
import json
import os
import sys

path = sys.argv[1].split(".")
raw = os.environ.get("JSON_PAYLOAD", "")
obj = json.loads(raw)
for key in path:
    obj = obj.get(key) if isinstance(obj, dict) else None
    if obj is None:
        print("")
        raise SystemExit(0)
print(obj if isinstance(obj, str) else "")
PY
}

request_json() {
  local method="$1"
  local url="$2"
  local apikey="$3"
  local authorization="$4"
  local body="$5"
  local response
  local status
  response="$(curl -sS -X "$method" "$url" \
    -H "Content-Type: application/json" \
    -H "apikey: $apikey" \
    -H "Authorization: $authorization" \
    --data "$body" \
    -w '\n%{http_code}')"
  status="$(printf '%s' "$response" | tail -n 1)"
  body="$(printf '%s' "$response" | sed '$d')"
  printf '%s\n%s' "$status" "$body"
}

is_server_error() {
  local status="$1"
  [[ "$status" =~ ^5[0-9][0-9]$ ]]
}

login_response="$(request_json \
  "POST" \
  "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  "$SUPABASE_ANON_KEY" \
  "Bearer $SUPABASE_ANON_KEY" \
  "{\"email\":\"$DOGAREA_TEST_EMAIL\",\"password\":\"$DOGAREA_TEST_PASSWORD\"}")"

login_status="$(printf '%s' "$login_response" | head -n 1)"
login_body="$(printf '%s' "$login_response" | tail -n +2)"

if [[ "$login_status" != "200" ]]; then
  echo "[AuthSmoke] 로그인 실패 status=$login_status"
  exit 1
fi

access_token="$(extract_json_field "$login_body" "access_token")"
user_id="$(extract_json_field "$login_body" "user.id")"

if [[ -z "$access_token" || -z "$user_id" ]]; then
  echo "[AuthSmoke] access_token 또는 user.id 파싱에 실패했습니다."
  exit 1
fi

tiny_png_base64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7+7zEAAAAASUVORK5CYII="

echo "[AuthSmoke] start iterations=$ITERATIONS user_id=${user_id:0:8}..."

iteration=1
while [[ "$iteration" -le "$ITERATIONS" ]]; do
  echo "[AuthSmoke] iteration=$iteration"

  nearby_visibility_member="$(request_json \
    "POST" \
    "$SUPABASE_URL/functions/v1/nearby-presence" \
    "$SUPABASE_ANON_KEY" \
    "Bearer $access_token" \
    "{\"action\":\"set_visibility\",\"userId\":\"$user_id\",\"enabled\":true}")"
  nearby_visibility_member_status="$(printf '%s' "$nearby_visibility_member" | head -n 1)"
  nearby_visibility_app="$(request_json \
    "POST" \
    "$SUPABASE_URL/functions/v1/nearby-presence" \
    "$SUPABASE_ANON_KEY" \
    "Bearer $SUPABASE_ANON_KEY" \
    "{\"action\":\"set_visibility\",\"userId\":\"$user_id\",\"enabled\":true}")"
  nearby_visibility_app_status="$(printf '%s' "$nearby_visibility_app" | head -n 1)"
  if [[ "$nearby_visibility_app_status" == "401" ]]; then
    echo "[AuthSmoke] FAIL nearby-presence set_visibility returned 401 with app authorization policy"
    exit 1
  fi

  nearby_hotspots_member="$(request_json \
    "POST" \
    "$SUPABASE_URL/functions/v1/nearby-presence" \
    "$SUPABASE_ANON_KEY" \
    "Bearer $access_token" \
    "{\"action\":\"get_hotspots\",\"userId\":\"$user_id\",\"centerLat\":37.42199,\"centerLng\":126.68327,\"radiusKm\":1.0}")"
  nearby_hotspots_member_status="$(printf '%s' "$nearby_hotspots_member" | head -n 1)"
  nearby_hotspots_app="$(request_json \
    "POST" \
    "$SUPABASE_URL/functions/v1/nearby-presence" \
    "$SUPABASE_ANON_KEY" \
    "Bearer $SUPABASE_ANON_KEY" \
    "{\"action\":\"get_hotspots\",\"userId\":\"$user_id\",\"centerLat\":37.42199,\"centerLng\":126.68327,\"radiusKm\":1.0}")"
  nearby_hotspots_app_status="$(printf '%s' "$nearby_hotspots_app" | head -n 1)"
  if [[ "$nearby_hotspots_app_status" == "401" ]]; then
    echo "[AuthSmoke] FAIL nearby-presence get_hotspots returned 401 with app authorization policy"
    exit 1
  fi
  if is_server_error "$nearby_hotspots_member_status" || is_server_error "$nearby_hotspots_app_status"; then
    echo "[AuthSmoke] FAIL nearby-presence get_hotspots returned server error member=$nearby_hotspots_member_status app=$nearby_hotspots_app_status"
    echo "[AuthSmoke] member body=$(printf '%s' "$nearby_hotspots_member" | tail -n +2)"
    echo "[AuthSmoke] app body=$(printf '%s' "$nearby_hotspots_app" | tail -n +2)"
    exit 1
  fi

  upload_profile_member="$(request_json \
    "POST" \
    "$SUPABASE_URL/functions/v1/upload-profile-image" \
    "$SUPABASE_ANON_KEY" \
    "Bearer $access_token" \
    "{\"ownerId\":\"$user_id\",\"imageBase64\":\"$tiny_png_base64\",\"imageKind\":\"user\"}")"
  upload_profile_member_status="$(printf '%s' "$upload_profile_member" | head -n 1)"
  upload_profile_app="$(request_json \
    "POST" \
    "$SUPABASE_URL/functions/v1/upload-profile-image" \
    "$SUPABASE_ANON_KEY" \
    "Bearer $SUPABASE_ANON_KEY" \
    "{\"ownerId\":\"$user_id\",\"imageBase64\":\"$tiny_png_base64\",\"imageKind\":\"user\"}")"
  upload_profile_app_status="$(printf '%s' "$upload_profile_app" | head -n 1)"
  if [[ "$upload_profile_app_status" == "401" ]]; then
    echo "[AuthSmoke] FAIL upload-profile-image returned 401 with app authorization policy"
    exit 1
  fi

  feature_control_member="$(request_json \
    "POST" \
    "$SUPABASE_URL/functions/v1/feature-control" \
    "$SUPABASE_ANON_KEY" \
    "Bearer $access_token" \
    "{\"action\":\"health_check\",\"source\":\"auth_smoke\"}")"
  feature_control_member_status="$(printf '%s' "$feature_control_member" | head -n 1)"
  feature_control_app="$(request_json \
    "POST" \
    "$SUPABASE_URL/functions/v1/feature-control" \
    "$SUPABASE_ANON_KEY" \
    "Bearer $SUPABASE_ANON_KEY" \
    "{\"action\":\"health_check\",\"source\":\"auth_smoke\"}")"
  feature_control_app_status="$(printf '%s' "$feature_control_app" | head -n 1)"
  if [[ "$feature_control_app_status" == "401" ]]; then
    echo "[AuthSmoke] FAIL feature-control returned 401 with app authorization policy"
    exit 1
  fi

  now_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  rpc_payload="{\"payload\":{\"period_type\":\"week\",\"top_n\":20,\"now_ts\":\"$now_ts\"}}"
  rival_rpc_member="$(request_json \
    "POST" \
    "$SUPABASE_URL/rest/v1/rpc/rpc_get_rival_leaderboard" \
    "$SUPABASE_ANON_KEY" \
    "Bearer $access_token" \
    "$rpc_payload")"
  rival_rpc_member_status="$(printf '%s' "$rival_rpc_member" | head -n 1)"
  if [[ "$rival_rpc_member_status" == "401" ]]; then
    echo "[AuthSmoke] FAIL rpc_get_rival_leaderboard returned 401 with member token"
    exit 1
  fi

  echo "[AuthSmoke] nearby_visibility member=$nearby_visibility_member_status app=$nearby_visibility_app_status"
  echo "[AuthSmoke] nearby_hotspots member=$nearby_hotspots_member_status app=$nearby_hotspots_app_status"
  echo "[AuthSmoke] upload_profile member=$upload_profile_member_status app=$upload_profile_app_status"
  echo "[AuthSmoke] feature_control member=$feature_control_member_status app=$feature_control_app_status"
  echo "[AuthSmoke] rival_rpc member=$rival_rpc_member_status"
  iteration=$((iteration + 1))
done

echo "[AuthSmoke] PASS: app authorization policy endpoints returned no 401 responses"
