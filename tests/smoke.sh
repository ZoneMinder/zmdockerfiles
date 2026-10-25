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
# capture from an RTSP stream, motion detection, the event server's TLS WebSocket (a client logs
# in and receives the alarms), the ML hook writing detections to the event, running as PUID/PGID,
# sending mail, surviving a database outage, and a clean restart.
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
ZM_PUBLIC_URL=http://zm.test:${ZM_HTTP_PORT:-18080}
GO2RTC_WEBRTC_PORT=18555
ZMES_PORT=19000
ZMES_USE_HOOKS=yes
PUID=1234
PGID=1234
SMTP_HOST=mailpit
SMTP_PORT=1025
SMTP_TLS=off
SMTP_USER=zm@example.com
SMTP_PASS=Sm0ke"mail\\pass|1
SMTP_FROM=zm@example.com
EOF
compose() {
    docker compose -p "$project" --env-file "$env_file" -f docker-compose.yaml -f compose.build.yaml -f tests/compose.test.yaml --profile ml "$@"
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
# zmdc starts the event server a few seconds after ZoneMinder, so give it a minute.
zm 'for i in $(seq 30); do
        echo | openssl s_client -connect 127.0.0.1:9000 2>/dev/null | grep -q "^New, TLS" && exit 0
        sleep 2
    done; exit 1' || fail "no TLS WebSocket on 9000"

step "test camera"
# The camera loops a 30 s scene: 20 s of a heavily blurred COCO photo of a bus with people, then
# 10 s of the sharp photo. Each change is motion, so ZoneMinder opens events by itself, and the
# sharp frames give the detector something to find. -g 5 puts a keyframe every second; zmwatch
# restarts a camera that shows no image for 45s.
zm 'cd /var/cache/zoneminder && curl -fsSL --retry 3 -o test.jpg https://ultralytics.com/images/bus.jpg \
    && ffmpeg -loglevel error -y -loop 1 -t 20 -i test.jpg -loop 1 -t 10 -i test.jpg -filter_complex \
        "[0]scale=640:-2,boxblur=40:4[a];[1]scale=640:-2[b];[a][b]concat=n=2:v=1,format=yuv420p" \
        -r 5 -c:v libx264 -g 5 cycle.mp4 \
    && ffmpeg -loglevel error -y -stream_loop 19 -i cycle.mp4 -c copy test.mp4' || fail "make test video"
zm 'curl -fsS -X PUT "http://127.0.0.1:1984/api/streams?name=test&src=ffmpeg:/var/cache/zoneminder/test.mp4%23video=copy"' \
    || fail "go2rtc stream"
# Live view: browsers reach go2rtc through Apache at <ZM_PUBLIC_URL>/zm/go2rtc/, and zmc calls the
# same URL from inside the container. The WebSocket has to pass go2rtc's origin check (101, not 403).
zm 'url=$ZM_PUBLIC_URL/zm/go2rtc/api
    curl -fsS -o /dev/null --max-time 10 "$url/streams" || { echo "$url/streams unreachable"; exit 1; }
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 -H "Origin: $ZM_PUBLIC_URL" \
        -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" \
        -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" "$url/ws?src=test" || true)
    [[ "$code" == 101 ]] || { echo "go2rtc WebSocket answered $code"; exit 1; }' \
    || fail "go2rtc live view through /zm/go2rtc/"
# From outside the container, go2rtc's unauthenticated API is closed except the live view
# WebSocket for ZoneMinder's stream names.
outside() {  # outside <expected code> <description> <curl args...>
    local want=$1 what=$2 code; shift 2
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$@" || true)
    [[ "$code" == "$want" ]] || fail "outside: $what answered $code, expected $want"
}
g2=http://127.0.0.1:${ZM_HTTP_PORT:-18080}/zm/go2rtc
wsh=(-H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13"
     -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" -H "Origin: http://127.0.0.1:${ZM_HTTP_PORT:-18080}")
outside 403 "go2rtc config" "$g2/api/config"
outside 403 "go2rtc stream list" "$g2/api/streams"
outside 403 "adding a go2rtc stream" -X PUT "$g2/api/streams?name=9&src=rtsp://example"
outside 403 "go2rtc web page" "$g2/"
outside 403 "WebSocket with a URL as source" "${wsh[@]}" "$g2/api/ws?src=rtsp://example"
outside 101 "WebSocket for a monitor stream" "${wsh[@]}" "$g2/api/ws?src=1_CameraDirectPrimary"
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
# A monitor made through the API has no zones, so add the web UI's default: the whole frame,
# alarm at 3% of the pixels.
zones=$(api zones/forMonitor/1.json | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["zones"]))')
if [[ "$zones" == 0 ]]; then
    api zones.json -X POST --data-urlencode "Zone[MonitorId]=1" --data-urlencode "Zone[Name]=All" \
        --data-urlencode "Zone[Type]=Active" --data-urlencode "Zone[Units]=Percent" \
        --data-urlencode "Zone[NumCoords]=4" --data-urlencode "Zone[Coords]=0,0 639,0 639,853 0,853" \
        --data-urlencode "Zone[Area]=546560" --data-urlencode "Zone[AlarmRGB]=16711680" \
        --data-urlencode "Zone[CheckMethod]=Blobs" --data-urlencode "Zone[MinPixelThreshold]=25" \
        --data-urlencode "Zone[MinAlarmPixels]=16396" --data-urlencode "Zone[MaxAlarmPixels]=409920" \
        --data-urlencode "Zone[FilterX]=3" --data-urlencode "Zone[FilterY]=3" \
        --data-urlencode "Zone[MinFilterPixels]=16396" --data-urlencode "Zone[MaxFilterPixels]=409920" \
        --data-urlencode "Zone[MinBlobPixels]=10931" --data-urlencode "Zone[MinBlobs]=1" >/dev/null \
        || fail "add zone"
    # zmc reads zones when it starts.
    zm 'zmdc.pl restart zmc -m 1 >/dev/null'
fi

step "motion, object detection and the event server"
# The event server only picks up new monitors on its periodic reload, so restart it.
zm 'zmdc.pl restart zmeventnotification.pl >/dev/null && sleep 8'
# A zmNinja-style client: logs in over the WebSocket and waits for the next event's start and end
# alarms. The event server sends the start alarm after the hook's detection, with the result in it.
# The event server checks passwords even when ZoneMinder's auth is off; admin's is then "admin".
es_pass=admin
[[ "$auth" == on ]] && es_pass=$admin_pass
es=$(compose exec -T -e ES_USER="$admin_user" -e ES_PASS="$es_pass" zoneminder \
    perl - 1 180 < tests/es-client.pl 2>&1) || fail "event server client: $es"
echo "$es"
start=$(grep -m1 '^start ' <<<"$es")
[[ "$start" == *detected:*bus* || "$start" == *detected:*person* ]] || fail "start alarm has no detection: $start"
eid=$(awk '{print $2}' <<<"$start")
notes=$(api "events/$eid.json" | python3 -c 'import json,sys;print(json.load(sys.stdin)["event"]["Event"]["Notes"])')
echo "event $eid notes: $notes"
[[ "$notes" == *detected:* ]] || fail "no detections written to event $eid"
[[ "$notes" == *Motion* ]] || fail "event $eid wasn't started by motion detection"

step "PUID/PGID and mail"
[[ "$(zm 'id -u www-data'):$(zm 'id -g www-data')" == 1234:1234 ]] || fail "www-data is not 1234:1234"
for p in /var/cache/zoneminder/events /config/es /var/log/zm /opt/zoneminder/venv; do
    [[ "$(zm "stat -c %u:%g $p")" == 1234:1234 ]] || fail "$p is $(zm "stat -c %u:%g $p"), not 1234:1234"
done
[[ "$(zm 'stat -c %u /etc/zm/zm.conf')" == 1234 ]] || fail "/etc/zm/zm.conf doesn't belong to 1234"
[[ "$(zm 'ps -o uid= -C zmc | sort -u | tr -d " "')" == 1234 ]] || fail "zmc isn't running as 1234"
compose exec -T -u www-data zoneminder sh -c 'printf "Subject: zm smoke\n\nhello\n" | msmtp -t admin@example.com' \
    || fail "msmtp couldn't send as www-data"
zm 'curl -fsS http://mailpit:8025/api/v1/messages' | grep -q '"Subject":"zm smoke"' || fail "mail didn't arrive"
echo "running as 1234:1234, mail delivered"

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
! grep -m3 'PHP Fatal' <<< "$logs" || fail "PHP fatal errors in the log"

echo; echo "PASS: ZoneMinder $version"
