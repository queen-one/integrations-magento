#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LAB_DIR="${MAGENTO_LAB_DIR:-${REPOSITORY_ROOT}/.local/magento}"
MAGENTO_DOMAIN="${MAGENTO_DOMAIN:-queenone-magento.test}"
RUN_COMPILE="${MAGENTO_RUN_COMPILE:-0}"

if [ ! -f "${LAB_DIR}/src/app/etc/env.php" ]; then
    echo "Magento is not installed. Run: make magento-install" >&2
    exit 1
fi

cd "${LAB_DIR}"
bin/start

echo "Checking runtime versions..."
bin/cli php -v | sed -n '1p'
bin/magento --version

echo "Checking the module mount and PHP syntax..."
if bin/cli test -e app/code/QueenOne/Connect/.local/magento; then
    echo "FAIL: the generated Magento lab is recursively mounted inside QueenOne_Connect" >&2
    exit 1
fi
echo "PASS: generated lab is masked from the module mount"
bin/cli bash -c 'find app/code/QueenOne/Connect -path app/code/QueenOne/Connect/.local -prune -o -name "*.php" -print0 | xargs -0 -n1 php -l >/dev/null'
echo "PASS: all module PHP files lint"

echo "Checking module and Magento schema status..."
bin/magento module:status QueenOne_Connect
bin/magento setup:db:status
bin/cli php app/code/QueenOne/Connect/dev/magento/check-tracking.php

assert_schema_object() {
    label="$1"
    query="$2"
    value="$(bin/mysql --batch --skip-column-names --execute "${query}" | tr -d '[:space:]')"
    if [ "${value}" != "1" ]; then
        echo "FAIL: ${label} is missing" >&2
        return 1
    fi
    echo "PASS: ${label} exists"
}

schema_failed=0
assert_schema_object \
    "queen_one_order_boundary table" \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'queen_one_order_boundary';" \
    || schema_failed=1
assert_schema_object \
    "queen_one_order_outbox table" \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'queen_one_order_outbox';" \
    || schema_failed=1

if [ "${RUN_COMPILE}" = "1" ]; then
    echo "Running dependency-injection compilation..."
    bin/magento setup:di:compile
fi

echo "Checking storefront response..."
curl --fail --insecure --silent --show-error --max-time 30 \
    "https://${MAGENTO_DOMAIN}/" >/dev/null
echo "PASS: storefront responds"

if [ "${schema_failed}" != "0" ]; then
    echo "Smoke test failed because the module did not create its complete schema." >&2
    exit 1
fi

echo "Local Magento smoke test passed."
