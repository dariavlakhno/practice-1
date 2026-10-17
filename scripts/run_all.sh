set -euo pipefail
cd "$(dirname "$0")/.."

run() {
  echo "==> $1"
  local s=$(date +%s.%N)
  docker exec trino trino --file "/sql/$1"
  local e=$(date +%s.%N)
  printf "    время шага: %.1f c\n" "$(echo "$e - $s" | bc)"
}

docker exec trino trino --execute "
DROP TABLE IF EXISTS iceberg.gold.shipping_priority_top10;
DROP TABLE IF EXISTS iceberg.silver.order_lines;
DROP TABLE IF EXISTS iceberg.bronze.lineitem;
DROP TABLE IF EXISTS iceberg.bronze.orders;
DROP TABLE IF EXISTS iceberg.bronze.customer;" >/dev/null 2>&1 || true

run 01_bronze.sql
run 02_silver.sql
run 03_gold.sql
run 04_verify.sql
