#!/usr/bin/env bash
# End-to-end test of the compose stack. CI runs it, and it runs the same way locally:
#
#   tests/smoke.sh            # builds zm-es + pyzm-serve, tests, tears everything down
#   NO_BUILD=1 tests/smoke.sh # reuse images you already built
#   ZM_CHANNEL=master tests/smoke.sh   # test the nightly build
#   NO_BUILD=1 ZM_IMAGE=zoneminder/zoneminder ZM_TAG=latest-es PYZM_IMAGE=zoneminder/pyzm-serve tests/smoke.sh
#                             # test published images
#   KEEP=1 tests/smoke.sh     # leave the stack running afterwards
#
# Checks: DB schema creation, ZoneMinder's first-run setup (1.39+), health, web UI and API, go2rtc,
# capture from an RTSP stream, event recording, the event server's TLS WebSocket, the ML hook
# writing detections to the event, surviving a database outage, and a clean restart.
set -euo pipefail

cd "$(dirname "$0")/.."
project="${PROJECT:-zmsmoke}"
workdir="$(mktemp -d)"
env_file="$workdir/test.env"
cat > "$env_file" <<EOF
TZ=UTC
ZM_DB_PASS=smoke-p@ss"w/rd#1
MARIADB_ROOT_PASSWORD=smoke-root
ZM_TARGET=zm-es
ZM_CHANNEL=${ZM_CHANNEL:-release}
ZM_VERSION=${ZM_VERSION:-}
BASE_IMAGE=${BASE_IMAGE:-debian:stable-slim}
ZM_IMAGE=${ZM_IMAGE:-zmsmoke}
ZM_TAG=${ZM_TAG:-es}
PYZM_IMAGE=${PYZM_IMAGE:-zmsmoke-pyzm-serve}
PYZM_TAG=${PYZM_TAG:-latest}
ZM_HTTP_PORT=${ZM_HTTP_PORT:-18080}
GO2RTC_API_PORT=11984
GO2RTC_WEBRTC_PORT=18555
ZMES_PORT=19000
ZMES_USE_HOOKS=yes
EOF
compose() {
    docker compose -p "$project" --env-file "$env_file" -f docker-compose.yaml -f compose.build.yaml --profile ml "$@"
}
zm() { compose exec -T zoneminder bash -c "$1"; }
admin_user=admin
admin_pass='Sm0ke-test|p&ss"w'"'"'rd-2026'

# ZoneMinder API call from inside the container, with the login token once we have one.
token=""
api() {
    local path=$1 sep='?'; shift
    [[ "$path" == *\?* ]] && sep='&'
    compose exec -T zoneminder curl -fsS --max-time 30 "$@" "http://127.0.0.1/zm/api/${path}${token:+${sep}token=$token}"
}
# 1.39+ first run: fill in the login page's "set the admin password" form, as a person would.
first_run() {
    compose exec -T -e P="$admin_pass" zoneminder bash -c '
        jar=$(mktemp)
        page=$(curl -fsS -c "$jar" -b "$jar" "http://127.0.0.1/zm/index.php?view=login")
        nonce=$(grep -o "name=\"first_run_nonce\" value=\"[^\"]*\"" <<< "$page" | head -1 | sed "s/.*value=\"//; s/\"\$//")
        [[ -n "$nonce" ]] || { echo "no first-run form on the login page" >&2; exit 1; }
        curl -fsS -o /dev/null -c "$jar" -b "$jar" "http://127.0.0.1/zm/index.php?view=login" \
            --data-urlencode action=setup --data-urlencode first_run_auth=on \
            --data-urlencode "first_run_nonce=$nonce" --data-urlencode username=admin \
            --data-urlencode "new_password=$P" --data-urlencode "new_password_confirm=$P"'
}
login() {
    compose exec -T -e U="$admin_user" -e P="$admin_pass" zoneminder sh -c \
        'curl -fsS --max-time 30 --data-urlencode "user=$U" --data-urlencode "pass=$P" http://127.0.0.1/zm/api/host/login.json' \
        | python3 -c 'import json,sys;print(json.load(sys.stdin)["access_token"])'
}

step() { echo; echo "==> $*"; }
fail() {
    echo "FAIL: $*" >&2
    compose ps || true
    compose logs --no-color --tail 200 zoneminder pyzm-serve || true
    exit 1
}
cleanup() {
    if [[ "${KEEP:-0}" != 1 ]]; then compose down -v --remove-orphans >/dev/null 2>&1 || true; fi
    rm -rf "$workdir"
}
trap cleanup EXIT

wait_healthy() {
    local svc=$1 timeout=${2:-300} id status
    id=$(compose ps -q "$svc")
    for ((i = 0; i < timeout; i += 5)); do
        status=$(docker inspect -f '{{.State.Health.Status}}' "$id" 2>/dev/null || echo missing)
        [[ "$status" == healthy ]] && return 0
        [[ "$(docker inspect -f '{{.State.Running}}' "$id")" == true ]] || fail "$svc exited"
        sleep 5
    done
    fail "$svc not healthy after ${timeout}s (last status: $status)"
}

if [[ "${NO_BUILD:-0}" != 1 ]]; then
    step "build"
    compose build
fi

step "start stack"
compose up -d
wait_healthy zoneminder
wait_healthy pyzm-serve 180

step "web UI, first-run setup and API"
zm 'curl -fsS -o /dev/null http://127.0.0.1/zm/' || fail "web UI"
auth=off
code=$(zm 'curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/zm/api/host/getVersion.json')
if [[ "$code" == 401 ]]; then
    auth=on
    echo "authentication is on: setting the admin password on the first-run page"
    first_run || fail "first-run setup failed"
    token=$(login) || fail "login with the new admin password failed"
    [[ -n "$token" ]] || fail "login returned no token"
    # What the README tells users to do: give the event server hook the ZoneMinder login.
    compose exec -T -e U="$admin_user" -e P="$admin_pass" zoneminder perl -i -pe '
        BEGIN { ($u, $p) = @ENV{qw(U P)}; s/\x27/\x27\x27/g for $u, $p }
        s/^(\s*ZM_USER:).*/$1 \x27$u\x27/; s/^(\s*ZM_PASSWORD:).*/$1 \x27$p\x27/' /config/es/secrets.yml \
        || fail "could not write secrets.yml"
elif [[ "$code" != 200 ]]; then
    fail "API returned HTTP $code"
fi
echo "authentication $auth"
version=$(api host/getVersion.json | python3 -c 'import json,sys;print(json.load(sys.stdin)["version"])')
echo "ZoneMinder $version"
db_version=$(zm 'source /etc/s6-overlay/scripts/common.sh; sql "SELECT Value FROM Config WHERE Name=\"ZM_DYN_DB_VERSION\""')
[[ "$db_version" == "$version" ]] || fail "DB version $db_version != $version"
secret=$(zm 'source /etc/s6-overlay/scripts/common.sh; sql "SELECT Value FROM Config WHERE Name=\"ZM_AUTH_HASH_SECRET\""')
[[ "$secret" != "...Change me to something unique..." ]] || fail "auth hash secret still default"

step "event server TLS on 9000"
zm 'echo | openssl s_client -connect 127.0.0.1:9000 2>/dev/null | grep -q "^New, TLS"' || fail "no TLS WebSocket on 9000"

step "test camera"
# The test frame is a COCO sample photo of a bus with people, so the detector has something to find.
# -g 5 puts a keyframe every second; zmwatch restarts a camera that shows no image for 45s.
zm 'curl -fsSL --retry 3 -o /var/cache/zoneminder/test.jpg https://ultralytics.com/images/bus.jpg \
    && ffmpeg -loglevel error -y -loop 1 -i /var/cache/zoneminder/test.jpg -t 600 -r 5 -vf scale=640:-2 \
        -c:v libx264 -g 5 -pix_fmt yuv420p /var/cache/zoneminder/test.mp4' || fail "make test video"
zm 'curl -fsS -X PUT "http://127.0.0.1:1984/api/streams?name=test&src=ffmpeg:/var/cache/zoneminder/test.mp4%23video=copy"' \
    || fail "go2rtc stream"
# The usage statistics prompt blocks image URLs until answered. Test shortcut for clicking "decline".
zm 'source /etc/s6-overlay/scripts/common.sh; sql "UPDATE Config SET Value=0 WHERE Name=\"ZM_SHOW_PRIVACY\""'
api monitors.json -X POST \
    --data-urlencode "Monitor[Name]=test" --data-urlencode "Monitor[Type]=Ffmpeg" \
    --data-urlencode "Monitor[Device]=/dev/video0" --data-urlencode "Monitor[Method]=rtpRtsp" \
    --data-urlencode "Monitor[Path]=rtsp://127.0.0.1:8554/test" \
    --data-urlencode "Monitor[Width]=640" --data-urlencode "Monitor[Height]=854" --data-urlencode "Monitor[Colours]=4" \
    --data-urlencode "Monitor[Capturing]=Always" --data-urlencode "Monitor[Analysing]=Always" \
    --data-urlencode "Monitor[Recording]=OnMotion" >/dev/null || fail "create monitor"
for ((i = 0; i < 60; i += 3)); do
    fps=$(api monitors/1.json \
        | python3 -c 'import json,sys;print(float(json.load(sys.stdin)["monitor"]["Monitor_Status"]["CaptureFPS"] or 0))' 2>/dev/null || echo 0)
    python3 -c "import sys;sys.exit(0 if $fps > 0 else 1)" && break
    sleep 3
done
python3 -c "import sys;sys.exit(0 if $fps > 0 else 1)" || fail "monitor is not capturing"
echo "capturing at $fps fps"

step "event + object detection"
# The event server only picks up new monitors on its periodic reload, so restart it.
zm 'zmdc.pl restart zmeventnotification.pl >/dev/null && sleep 8'
api monitors/alarm/id:1/command:on.json -o /dev/null || fail "forcing an alarm failed"
sleep 12
api monitors/alarm/id:1/command:off.json -o /dev/null || fail "cancelling the alarm failed"
notes=""
for ((i = 0; i < 90; i += 5)); do
    notes=$(api events.json \
        | python3 -c 'import json,sys;e=json.load(sys.stdin)["events"];print(e[-1]["Event"]["Notes"] if e else "")')
    [[ "$notes" == *detected:* ]] && break
    sleep 5
done
echo "event notes: $notes"
[[ "$notes" == *detected:*bus* || "$notes" == *detected:*person* ]] || fail "no detections written to the event"

step "database outage"
# zmdc keeps capturing through a DB outage, so the container must stay up and only report unhealthy.
zid=$(compose ps -q zoneminder)
started=$(docker inspect -f '{{.State.StartedAt}}' "$zid")
compose stop db >/dev/null
sleep 45
[[ "$(docker inspect -f '{{.State.StartedAt}}' "$zid")" == "$started" ]] || fail "container restarted during a DB outage"
reason=$(zm '/usr/local/bin/zm-healthcheck' || true)
[[ "$reason" == *"database not reachable"* ]] || fail "healthcheck should name the database, got: $reason"
echo "with DB down: $reason"
compose start db >/dev/null
wait_healthy db 120
wait_healthy zoneminder 120
[[ "$(docker inspect -f '{{.State.StartedAt}}' "$zid")" == "$started" ]] || fail "container restarted during a DB outage"

step "restart"
compose restart zoneminder
wait_healthy zoneminder
logs=$(compose logs --no-color zoneminder)
[[ $(grep -c 'empty database, loading' <<< "$logs") == 1 ]] || fail "schema should load once, on first start only"
[[ $(grep -c 'running zmupdate.pl' <<< "$logs") -ge 1 ]] || fail "second start did not run zmupdate.pl"

echo; echo "PASS: ZoneMinder $version"
