
SELECT snapshot_id, committed_at, operation FROM iceberg.silver."order_lines$snapshots" ORDER BY committed_at;


ALTER TABLE iceberg.silver.order_lines ADD COLUMN source_system varchar;
SELECT orderkey, revenue_line, source_system FROM iceberg.silver.order_lines LIMIT 3;


ALTER TABLE iceberg.silver.order_lines RENAME COLUMN revenue_line TO line_revenue;
SELECT orderkey, line_revenue FROM iceberg.silver.order_lines LIMIT 3;


DELETE FROM iceberg.silver.order_lines WHERE shippriority = 0;
SELECT count(*) AS rows_after_delete FROM iceberg.silver.order_lines;


SELECT snapshot_id, committed_at, operation FROM iceberg.silver."order_lines$snapshots" ORDER BY committed_at;

