-- ЧАСТЬ 2: schema evolution и time travel на Silver

-- 0. Снапшоты до изменений
SELECT snapshot_id, committed_at, operation FROM iceberg.silver."order_lines$snapshots" ORDER BY committed_at;

-- 1. Добавляем колонку (старые строки получат NULL, файлы НЕ переписываются)
ALTER TABLE iceberg.silver.order_lines ADD COLUMN source_system varchar;
SELECT orderkey, revenue_line, source_system FROM iceberg.silver.order_lines LIMIT 3;

-- 2. Переименовываем колонку (данные на месте — Iceberg ведёт колонки по id, а не по имени)
ALTER TABLE iceberg.silver.order_lines RENAME COLUMN revenue_line TO line_revenue;
SELECT orderkey, line_revenue FROM iceberg.silver.order_lines LIMIT 3;

-- 3. «Авария»: случайно удаляем данные
DELETE FROM iceberg.silver.order_lines WHERE shippriority = 0;
SELECT count(*) AS rows_after_delete FROM iceberg.silver.order_lines;

-- 4. Смотрим историю снапшотов — берём snapshot_id ДО DELETE (самый ранний с операцией append)
SELECT snapshot_id, committed_at, operation FROM iceberg.silver."order_lines$snapshots" ORDER BY committed_at;

-- 5. Time travel: читаем таблицу как она была (подставь свой snapshot_id)
-- SELECT count(*) FROM iceberg.silver.order_lines FOR VERSION AS OF <snapshot_id>;

-- 6. Восстановление: откат таблицы на снапшот (подставь свой snapshot_id)
-- CALL iceberg.system.rollback_to_snapshot('silver', 'order_lines', <snapshot_id>);
-- SELECT count(*) AS rows_after_restore FROM iceberg.silver.order_lines;
