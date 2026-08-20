#!/bin/bash
# check_all.sh — regresná poistka pre Regnum Moravicum
# Spustí všetky 4 kontroly jedným príkazom.
# Usage: cd godot && bash tools/check_all.sh

set -e
GODOT="godot --headless --path ."
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

failures=0

check() {
    local name="$1"
    shift
    echo -n "  $name ... "
    # Temporarily disable set -e so we can capture real exit status
    set +e
    local output exit_status
    output=$("$@" 2>&1)
    exit_status=$?
    set -e

    # Fail on any FAIL marker (M5 or M6) — must be before success markers
    if echo "$output" | grep -qE "(FAIL:|SMOKE_FAIL|SMOKE_M5_FAIL|SMOKE_M6_FAIL)"; then
        echo -e "${RED}FAIL${NC} (FAIL marker detected)"
        echo "$output" | grep -E "(FAIL:|SMOKE_FAIL|SMOKE_M5_FAIL|SMOKE_M6_FAIL)"
        failures=$((failures + 1))
    # Fail on any SCRIPT ERROR or Parse Error (runtime errors in Godot)
    elif echo "$output" | grep -qE "(SCRIPT ERROR|Parse Error)"; then
        echo -e "${RED}FAIL${NC} (SCRIPT ERROR detected)"
        echo "$output" | grep -E "(SCRIPT ERROR|Parse Error)"
        failures=$((failures + 1))
    # Fail on non-zero process exit (crash, segfault, timeout)
    elif [ $exit_status -ne 0 ]; then
        echo -e "${RED}FAIL${NC} (exit code $exit_status)"
        echo "$output" | tail -5
        failures=$((failures + 1))
    # Pass on recognised success marker
    elif echo "$output" | grep -qE "(SMOKE_PASS|SMOKE_M6_PASS|TURNREPORT_RUNTIME_PASS|Tests [0-9]+ passed)"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC} (no success marker)"
        echo "$output" | tail -5
        failures=$((failures + 1))
    fi
}

echo "=== Regnum Moravicum — regresná kontrola ==="
echo ""

# 1. Main.tscn headless boot (najdôležitejšie — zachytí parse errory a exit kód)
echo "1. Main.tscn boot"
echo -n "  Main.tscn boot ... "
set +e
main_output=$($GODOT res://scenes/main/Main.tscn --quit-after 4 2>&1)
main_rc=$?
set -e
if echo "$main_output" | grep -qE "(Parse Error|SCRIPT ERROR)"; then
    echo -e "${RED}FAIL${NC} (SCRIPT ERROR detected)"
    echo "$main_output" | grep -E "(Parse Error|SCRIPT ERROR)"
    failures=$((failures + 1))
elif [ $main_rc -ne 0 ]; then
    echo -e "${RED}FAIL${NC} (exit code $main_rc)"
    echo "$main_output" | tail -3
    failures=$((failures + 1))
else
    echo -e "${GREEN}PASS${NC}"
fi

# 2. Smoke M5
echo "2. Smoke M5"
check "Smoke M5" $GODOT -s res://tools/smoke_test.gd --quit-after 30

# 3. Smoke M6
echo "3. Smoke M6"
check "Smoke M6" $GODOT -s res://tools/smoke_test.m6.gd --quit-after 30

# 4. TurnReport runtime behavior test (autoloads enabled)
echo "4. TurnReport runtime"
check "TurnReport runtime" $GODOT res://tools/test_turnreport_runtime.tscn --quit-after 10

# 5. TS tests (run from project root)
echo "5. npm test"
echo -n "  npm test ... "
set +e
ts_output=$(cd "$PROJECT_ROOT" && npm run test 2>&1)
ts_rc=$?
set -e
if [ $ts_rc -ne 0 ]; then
    echo -e "${RED}FAIL${NC} (exit code $ts_rc)"
    echo "$ts_output" | tail -5
    failures=$((failures + 1))
elif echo "$ts_output" | grep -q "305 passed"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC} (unexpected)"
    echo "$ts_output" | tail -5
    failures=$((failures + 1))
fi

echo ""
if [ $failures -eq 0 ]; then
    echo -e "${GREEN}Všetky kontroly prešli.${NC}"
else
    echo -e "${RED}${failures} kontrola/y zlyhala/y.${NC}"
fi
exit $failures