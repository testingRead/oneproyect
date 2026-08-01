#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BINARY="${GODOT_BINARY:-$HOME/toolchains/godot-4.7.1/godot}"
TEST_WORKERS="${TEST_WORKERS:-6}"
GRADLE_WORKERS="${GRADLE_WORKERS:-6}"
BUILD_APK="${BUILD_APK:-1}"
LOG_DIR="${LOG_DIR:-}"
TMP_BASE="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"

if ! command -v grun >/dev/null 2>&1; then
	echo "Falta grun (glibc-runner) en Termux" >&2
	exit 2
fi
if [[ ! -x "$GODOT_BINARY" ]]; then
	echo "Godot ARM64 no es ejecutable: $GODOT_BINARY" >&2
	exit 2
fi
if (( TEST_WORKERS < 1 || TEST_WORKERS > 6 )); then
	echo "TEST_WORKERS debe estar entre 1 y 6" >&2
	exit 2
fi

if [[ -z "$LOG_DIR" ]]; then
	LOG_DIR="$(mktemp -d "$TMP_BASE/oneproyect-validation.XXXXXX")"
else
	mkdir -p "$LOG_DIR"
fi

TESTS=(
	avatar_asset_test
	local_base_test
	local_round_test
	crown_round_test
	bomb_round_test
	tornado_round_test
	bateball_round_test
	elimination_ball_round_test
	shooter_round_test
	session_score_test
	network_codec_test
	server_room_test
	menu_smoke_test
	smoke_test
)

declare -a active_pids=()
declare -a active_names=()
failed=0

wait_batch() {
	local index
	local status
	for index in "${!active_pids[@]}"; do
		status=0
		wait "${active_pids[$index]}" || status=$?
		if grep -qE "SCRIPT ERROR|Parse Error|TEST_FAIL|ERROR:" \
			"$LOG_DIR/${active_names[$index]}.log"; then
			status=90
		fi
		if (( status != 0 )); then
			failed=1
			echo "TEST_FAIL ${active_names[$index]} exit=$status" >&2
			tail -n 100 "$LOG_DIR/${active_names[$index]}.log" >&2
		else
			echo "TEST_OK ${active_names[$index]}"
		fi
	done
	active_pids=()
	active_names=()
}

for test_name in "${TESTS[@]}"; do
	grun "$GODOT_BINARY" \
		--headless \
		--path "$PROJECT_DIR" \
		--script "res://tests/$test_name.gd" \
		>"$LOG_DIR/$test_name.log" 2>&1 &
	active_pids+=("$!")
	active_names+=("$test_name")
	if (( ${#active_pids[@]} >= TEST_WORKERS )); then
		wait_batch
	fi
done
if (( ${#active_pids[@]} > 0 )); then
	wait_batch
fi
if (( failed != 0 )); then
	echo "VALIDATION_ABORTED logs=$LOG_DIR" >&2
	exit 3
fi

# ENet LAN needs two simultaneous peers and therefore runs after the isolated
# suite, when no other test can contend for its UDP port.
grun "$GODOT_BINARY" \
	--headless --path "$PROJECT_DIR" \
	--script res://tests/lan_host_probe.gd \
	>"$LOG_DIR/lan_host_probe.log" 2>&1 &
host_pid=$!
sleep 0.8
grun "$GODOT_BINARY" \
	--headless --path "$PROJECT_DIR" \
	--script res://tests/lan_client_probe.gd \
	>"$LOG_DIR/lan_client_probe.log" 2>&1 &
client_pid=$!
host_status=0
client_status=0
wait "$host_pid" || host_status=$?
wait "$client_pid" || client_status=$?
if (( host_status != 0 || client_status != 0 )); then
	tail -n 120 "$LOG_DIR/lan_host_probe.log" >&2
	tail -n 120 "$LOG_DIR/lan_client_probe.log" >&2
	echo "LAN_VALIDATION_FAIL host=$host_status client=$client_status" >&2
	exit 4
fi
grep -q "LAN_HOST_OK" "$LOG_DIR/lan_host_probe.log"
grep -q "LAN_CLIENT_OK" "$LOG_DIR/lan_client_probe.log"
echo "LAN_VALIDATION_OK"

if [[ "$BUILD_APK" == "1" ]]; then
	cd "$PROJECT_DIR/tools/android-native"
	GRADLE_WORKERS="$GRADLE_WORKERS" ./build-termux.sh
fi

echo "ANDROID_VALIDATION_OK logs=$LOG_DIR"
