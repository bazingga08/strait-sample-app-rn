#!/usr/bin/env bash
# Real-phone ANALYTICS suite: every way a link can reach (or miss) the app, and
# the exact rows Strait must record for each — taps, app opens, joins between
# them (same tap letter), new vs existing user, app state, failures. Since
# engine B16 a verified-link open records its tap AND joins it (same letter).
#   scripts/analytics-test.sh [path/to/app-release.apk]
# Needs: one Android phone on adb (Chrome, Samsung Internet, Firefox, Edge
# installed), the release APK, and redirect-engine/.env (database access).
# Play-install deferred linking is NOT covered (needs a real Play install).
set -u
APK="${1:-android/app/build/outputs/apk/release/app-release.apk}"
E="${STRAIT_ENGINE:-https://strait-dev.strait.link}"
T="${STRAIT_TENANT:-0a2b8762-edb7-4e07-9587-12c1f451c0ea}"   # strait-dev
P=com.straitlink.app
PAGE=https://bazingga08.github.io/strait-demo-site/open.html
HERE="$(cd "$(dirname "$0")" && pwd)"
pass=0; fail=0; results=()

adb get-state >/dev/null 2>&1 || { echo "No Android device connected."; exit 2; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
rows() { python3 "$HERE/analytics_rows.py" "$T" "$1"; }
home() { adb shell input keyevent KEYCODE_HOME; sleep 3; }
killapp() { adb shell am force-stop $P; sleep 1; }
direct() { adb shell am start -a android.intent.action.VIEW -d "$1" >/dev/null 2>&1; sleep 7; }   # like a Messages/WhatsApp tap
tapui() { python3 - "$1" <<'PY'
import re, subprocess, sys
subprocess.run(['adb','shell','uiautomator','dump','/sdcard/ui.xml'], capture_output=True)
xml = subprocess.run(['adb','shell','cat','/sdcard/ui.xml'], capture_output=True, text=True).stdout
pat = re.compile(sys.argv[1], re.I); attr = lambda n, k: (re.search(rf' {k}="([^"]*)"', n) or [None, ''])[1]
for n in re.findall(r'<node [^>]*>', xml):
    if pat.search(attr(n, 'text')) or pat.search(attr(n, 'content-desc')):
        x1, y1, x2, y2 = map(int, re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n).groups())
        subprocess.run(['adb','shell','input','tap',str((x1+x2)//2),str((y1+y2)//2)]); sys.exit(0)
sys.exit(1)
PY
}
# Open the link from a real web page in browser $1, tapping it like a person,
# then accept the browser's own "open in app?" prompt if it shows one.
from_page() {
  local u; u=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$E/$2?t=$(date +%s)")
  adb shell am force-stop "$1"; home
  adb shell am start -a android.intent.action.VIEW -d "$PAGE?u=$u" -p "$1" >/dev/null 2>&1; sleep 10
  tapui '^Cancel$' && sleep 2   # Firefox's "set as default browser?" dialog on cold start
  tapui '^Not now$' && sleep 2  # ...and its notifications nag
  tapui '^Open the link$' || adb shell input tap 540 1527   # some browsers hide web text from the UI tree
  sleep 5; tapui '^(Open|Open in app)$' && sleep 3; sleep 4
}
expect() {  # name, since, expected rows (one per line, any order)
  sleep 4
  local got want; got=$(rows "$2"); want=$(printf '%s\n' "$3" | sed '/^$/d' | sort)
  if [ "$got" = "$want" ]; then pass=$((pass+1)); results+=("PASS  $1")
  else fail=$((fail+1)); results+=("FAIL  $1"$'\n'"      expected:"$'\n'"$(sed 's/^/        /' <<<"$want")"$'\n'"      got:"$'\n'"$(sed 's/^/        /' <<<"$got")"); fi
}
install_app() {
  ( adb install -r "$APK" >/dev/null 2>&1 ) & local pid=$!; ( sleep 120; kill $pid 2>/dev/null ) & local w=$!
  wait $pid || { echo "Install failed or hung."; exit 3; }; kill $w 2>/dev/null; wait $w 2>/dev/null
  adb shell pm verify-app-links --re-verify $P; sleep 8
}
curl -s -o /dev/null -m 90 "$E/healthz/deep"
# Let late rows from a previous run (e.g. device-test.sh's last tap + open, reported
# asynchronously) land before the first scenario starts its time window.
sleep 20

echo "▶ 1. App not installed"
adb uninstall $P >/dev/null 2>&1; S=$(now)
adb shell am start -a android.intent.action.VIEW -d "$E/bl-promo?t=$(date +%s)" -p com.android.chrome --ez create_new_tab true >/dev/null 2>&1; sleep 10
expect "Not installed: Chrome tap → Play Store = 1 store-bound tap, no open" "$S" "TAP bl-promo web app_or_store tap=-"

echo "▶ 2. Install; first launch from a link"
install_app; S=$(now); direct "$E/bl-product?utm_source=whatsapp"
expect "First launch from a WhatsApp-style tap = tap + NEW USER open" "$S" "OPEN bl-product app_link closed new ok tap=A
TAP bl-product app_link - tap=A"

echo "▶ 3. App running"
home; S=$(now); direct "$E/bl-category"
expect "Background: tap + open (background, existing user)" "$S" "OPEN bl-category app_link background existing ok tap=A
TAP bl-category app_link - tap=A"
S=$(now); direct "$E/bl-invite"
expect "On screen: tap + open (foreground)" "$S" "OPEN bl-invite app_link foreground existing ok tap=A
TAP bl-invite app_link - tap=A"
killapp; S=$(now); direct "$E/bl-product"
expect "Closed (killed): tap + open (closed, existing user)" "$S" "OPEN bl-product app_link closed existing ok tap=A
TAP bl-product app_link - tap=A"

echo "▶ 4. Browsers hand off to the app"
home; S=$(now); adb shell am start -a android.intent.action.VIEW -d "$E/bl-promo?t=$(date +%s)" -p com.android.chrome --ez create_new_tab true >/dev/null 2>&1; sleep 10
expect "Chrome: one browser tap, the app's open joined to it" "$S" "OPEN bl-promo custom_scheme background existing ok tap=A
TAP bl-promo web app_or_store tap=A"
S=$(now); from_page com.sec.android.app.sbrowser bl-category
expect "Samsung Internet: one browser tap, open joined" "$S" "OPEN bl-category custom_scheme background existing ok tap=A
TAP bl-category web app_or_store tap=A"
S=$(now); from_page com.microsoft.emmx bl-promo
expect "Edge (loads link, then hands https to the app): ONE tap, open joined" "$S" "OPEN bl-promo app_link background existing ok tap=A
TAP bl-promo web app_or_store tap=A"
S=$(now); from_page org.mozilla.firefox bl-invite
expect "Firefox (hands https straight to the app): one tap + open" "$S" "OPEN bl-invite app_link background existing ok tap=A
TAP bl-invite app_link - tap=A"

echo "▶ 5. Offline"
home; adb shell svc wifi disable; adb shell svc data disable; sleep 4; S=$(now)
direct "$E/bl-order"; sleep 3
adb shell svc wifi enable; adb shell svc data enable
for i in $(seq 1 20); do sleep 2; adb shell ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 && break; done
home; adb shell monkey -p $P -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; sleep 8
expect "Offline tap: saved, sent on return — open (failed: network) + tap, once" "$S" "OPEN bl-order app_link background existing failed:network tap=A
TAP bl-order app_link - tap=A"

echo "▶ 6. Broken and non-Strait links"
S=$(now); direct "$E/bl-expired"; direct "$E/no-such-link-$(date +%s)"; direct "straitlink://shop.example/p/7?src=qr"
expect "Expired / deleted / plain-scheme: failed opens + an 'other' open, no taps" "$S" "OPEN - app_link foreground existing failed:not_found tap=-
OPEN - custom_scheme foreground existing ok tap=-
OPEN bl-expired app_link foreground existing failed:expired tap=-"

echo; printf '%s\n' "${results[@]}"
echo; echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
