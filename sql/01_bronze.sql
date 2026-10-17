CREATE SCHEMA IF NOT EXISTS iceberg.bronze;

CREATE TABLE iceberg.bronze.customer
WITH (format = 'PARQUET') AS
SELECT custkey, mktsegment
FROM tpch.sf1.customer;

CREATE TABLE iceberg.bronze.orders
WITH (format = 'PARQUET') AS
SELECT orderkey, custkey, orderdate, shippriority
FROM tpch.sf1.orders;

CREATE TABLE iceberg.bronze.lineitem
WITH (format = 'PARQUET') AS
SELECT orderkey, extendedprice, discount, shipdate
FROM tpch.sf1.lineitem;
