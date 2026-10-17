#!/usr/bin/env bash
# Бенчмарк кодеков сжатия на Bronze: для каждого кодека
#   1) создаёт schema bronze_<codec> и заливает 3 таблицы Q3 (меряет время записи),
#   2) считает размер файлов,
#   3) прогоняет Q3 (1 прогрев + 3 замера, берём минимум и среднее).
# Результат: bench_results.csv и готовые строки для отчёта.
set -euo pipefail
cd "$(dirname "$0")/.."

CODECS=${CODECS:-"NONE SNAPPY GZIP ZSTD"}
RUNS=3
OUT=bench_results.csv
echo "codec,write_s,size_mb,query_min_s,query_avg_s" > "$OUT"

now() { date +%s.%N; }
tr_q() { docker exec trino trino --output-format CSV_UNQUOTED --execute "$1"; }

for codec in $CODECS; do
  lc=$(echo "$codec" | tr 'A-Z' 'a-z')
  schema="bronze_${lc}"
  echo "==> Кодек $codec (схема iceberg.$schema)"

  tr_q "DROP TABLE IF EXISTS iceberg.${schema}.lineitem" >/dev/null 2>&1 || true
  tr_q "DROP TABLE IF EXISTS iceberg.${schema}.orders"   >/dev/null 2>&1 || true
  tr_q "DROP TABLE IF EXISTS iceberg.${schema}.customer" >/dev/null 2>&1 || true
  tr_q "CREATE SCHEMA IF NOT EXISTS iceberg.${schema}" >/dev/null

  s=$(now)
  docker exec trino trino --execute "
    CREATE TABLE iceberg.${schema}.customer WITH (format='PARQUET', compression_codec='${codec}') AS SELECT custkey, mktsegment FROM tpch.sf1.customer;
    CREATE TABLE iceberg.${schema}.orders   WITH (format='PARQUET', compression_codec='${codec}') AS SELECT orderkey, custkey, orderdate, shippriority FROM tpch.sf1.orders;
    CREATE TABLE iceberg.${schema}.lineitem WITH (format='PARQUET', compression_codec='${codec}') AS SELECT orderkey, extendedprice, discount, shipdate FROM tpch.sf1.lineitem;
  " >/dev/null
  e=$(now); write_s=$(echo "$e - $s" | bc)

  size_mb=$(tr_q "SELECT round(sum(b)/1024.0/1024.0, 2) FROM (
      SELECT sum(file_size_in_bytes) b FROM iceberg.${schema}.\"customer\$files\"
      UNION ALL SELECT sum(file_size_in_bytes) FROM iceberg.${schema}.\"orders\$files\"
      UNION ALL SELECT sum(file_size_in_bytes) FROM iceberg.${schema}.\"lineitem\$files\")" | tail -1)

  Q="SELECT l.orderkey, sum(l.extendedprice*(1-l.discount)) AS revenue, o.orderdate, o.shippriority
     FROM iceberg.${schema}.customer c
     JOIN iceberg.${schema}.orders o ON c.custkey=o.custkey
     JOIN iceberg.${schema}.lineitem l ON l.orderkey=o.orderkey
     WHERE c.mktsegment='BUILDING' AND o.orderdate < DATE '1995-03-15' AND l.shipdate > DATE '1995-03-15'
     GROUP BY l.orderkey, o.orderdate, o.shippriority ORDER BY revenue DESC LIMIT 10"

  tr_q "$Q" >/dev/null   # прогрев
  times=()
  for i in $(seq $RUNS); do
    s=$(now); tr_q "$Q" >/dev/null; e=$(now)
    times+=("$(echo "$e - $s" | bc)")
  done
  min=$(printf "%s\n" "${times[@]}" | sort -n | head -1)
  avg=$(printf "%s\n" "${times[@]}" | awk '{s+=$1} END {printf "%.2f", s/NR}')
  printf "%s,%.2f,%s,%.2f,%s\n" "$codec" "$write_s" "$size_mb" "$min" "$avg" >> "$OUT"
done

echo
echo "| Сжатие | Запись, c | Размер Bronze, МБ | Запрос min, c | Запрос avg, c |"
echo "|---|---|---|---|---|"
tail -n +2 "$OUT" | awk -F, '{printf "| %s | %s | %s | %s | %s |\n",$1,$2,$3,$4,$5}'
