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
    if "$@" 2>&1 | grep -qE "(SMOKE_PASS|SMOKE_M6_PASS|SMOKE_MAIN_PASS|Tests [0-9]+ passed)"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        failures=$((failures + 1))
    fi
}

echo "=== Regnum Moravicum — regresná kontrola ==="
echo ""

# 1. Main.tscn headless boot (najdôležitejšie — zachytí parse errory)
echo "1. Main.tscn boot"
$GODOT res://scenes/main/Main.tscn --quit-after 4 2>&1 | grep -E "(Parse Error|SCRIPT ERROR)" && echo -e "  ${RED}FAIL${NC}" && failures=$((failures + 1)) || echo -e "  ${GREEN}PASS${NC}"

# 2. Smoke M5
echo "2. Smoke M5"
check "Smoke M5" $GODOT -s res://tools/smoke_test.gd --quit-after 30

# 3. Smoke M6
echo "3. Smoke M6"
check "Smoke M6" $GODOT -s res://tools/smoke_test.m6.gd --quit-after 30

# 4. TS tests (run from project root)
echo "4. npm test"
echo -n "  npm test ... "
if (cd "$PROJECT_ROOT" && npm run test) 2>&1 | grep -q "305 passed"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    failures=$((failures + 1))
fi

echo ""
if [ $failures -eq 0 ]; then
    echo -e "${GREEN}Všetky kontroly prešli.${NC}"
else
    echo -e "${RED}${failures} kontrola/y zlyhala/y.${NC}"
fi
exit $failures