
CREATE SCHEMA IF NOT EXISTS iceberg.gold;

CREATE TABLE iceberg.gold.shipping_priority_top10
WITH (format = 'PARQUET') AS
SELECT
  orderkey,
  sum(revenue_line) AS revenue,
  orderdate,
  shippriority
FROM iceberg.silver.order_lines
GROUP BY orderkey, orderdate, shippriority
ORDER BY revenue DESC
LIMIT 10;

SELECT * FROM iceberg.gold.shipping_priority_top10 ORDER BY revenue DESC;
