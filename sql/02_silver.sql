-- SILVER: очистка, нормализация, обогащение.
--  * нормализация: mktsegment -> upper(trim(...))
--  * фильтрация: сегмент BUILDING, orderdate < 1995-03-15, shipdate > 1995-03-15
--  * обогащение: считаем revenue_line = extendedprice * (1 - discount) на уровне строки
--  * джойн customer + orders + lineitem в один факт «строки заказов»

CREATE SCHEMA IF NOT EXISTS iceberg.silver;

CREATE TABLE iceberg.silver.order_lines
WITH (format = 'PARQUET') AS
SELECT
  l.orderkey,
  o.orderdate,
  o.shippriority,
  l.extendedprice,
  l.discount,
  l.extendedprice * (1 - l.discount) AS revenue_line
FROM iceberg.bronze.customer AS c
JOIN iceberg.bronze.orders   AS o ON c.custkey = o.custkey
JOIN iceberg.bronze.lineitem AS l ON l.orderkey = o.orderkey
WHERE upper(trim(c.mktsegment)) = 'BUILDING'
  AND o.orderdate < DATE '1995-03-15'
  AND l.shipdate  > DATE '1995-03-15';
