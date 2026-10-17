set -euo pipefail

t() { docker exec trino trino --output-format CSV_UNQUOTED --execute "$1" | tail -1; }

echo "| Таблица | Строк | Вес, МБ |"
echo "|---|---|---|"
for tbl in bronze.customer bronze.orders bronze.lineitem silver.order_lines gold.shipping_priority_top10; do
  schema=${tbl%%.*}; name=${tbl##*.}
  rows=$(t "SELECT count(*) FROM iceberg.${schema}.${name}")
  mb=$(t "SELECT round(sum(file_size_in_bytes)/1024.0/1024.0, 2) FROM iceberg.${schema}.\"${name}\$files\"")
  echo "| ${tbl} | ${rows} | ${mb} |"
done
