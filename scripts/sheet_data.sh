cd "$(dirname "$0")/.."
now() { date +%s.%N; }
echo "кодек | файлов | первая агрегация, с | следующие (среднее из 3), с"
for c in none snappy gzip zstd; do
  files=0
  for t in customer orders lineitem; do
    n=$(docker exec trino trino --output-format CSV_UNQUOTED --execute "SELECT count(*) FROM iceberg.bronze_${c}.\"${t}\$files\"")
    files=$((files+n))
  done
  Q="SELECT l.orderkey, sum(l.extendedprice*(1-l.discount)) AS revenue, o.orderdate, o.shippriority FROM iceberg.bronze_${c}.customer c JOIN iceberg.bronze_${c}.orders o ON c.custkey=o.custkey JOIN iceberg.bronze_${c}.lineitem l ON l.orderkey=o.orderkey WHERE c.mktsegment='BUILDING' AND o.orderdate < DATE '1995-03-15' AND l.shipdate > DATE '1995-03-15' GROUP BY l.orderkey, o.orderdate, o.shippriority ORDER BY revenue DESC LIMIT 10"
  s=$(now); docker exec trino trino --execute "$Q" >/dev/null; e=$(now)
  first=$(echo "scale=2; $e - $s" | bc)
  sum=0
  for i in 1 2 3; do
    s=$(now); docker exec trino trino --execute "$Q" >/dev/null; e=$(now)
    sum=$(echo "$sum + $e - $s" | bc)
  done
  next=$(echo "scale=2; $sum / 3" | bc)
  echo "$c | $files | $first | $next"
done
