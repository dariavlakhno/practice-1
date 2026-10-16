# Практическая №1 — локальный Lakehouse (вариант 1, TPC-H Q3)

Автор: Влахно Дарья Максимовна, группа БИВТ-24-СП-4.

Стек: MinIO + PostgreSQL + Lakekeeper (Iceberg REST Catalog) + Trino + Metabase.
Данные: коннектор `tpch`, масштаб `sf1`. Подробный отчёт — в [otchet.md](otchet.md).

## Структура

```
docker-compose.yml        # весь стек
trino/catalog/            # каталоги Trino: iceberg (Lakekeeper+MinIO) и tpch
sql/01_bronze.sql         # сырой слой
sql/02_silver.sql         # очистка, нормализация, обогащение, джойн
sql/03_gold.sql           # витрина (ответ на Q3)
sql/04_verify.sql         # сверка Gold с исходным запросом
sql/05_evolution_timetravel.sql  # schema evolution и time travel
scripts/setup.sh          # поднять стек + создать warehouse
scripts/run_all.sh        # Bronze -> Silver -> Gold -> проверка
scripts/stats.sh          # строки и вес по таблицам (для отчёта)
scripts/bench.sh          # бенчмарк кодеков NONE/SNAPPY/GZIP/ZSTD
```

## Как воспроизвести

Нужны Docker с Docker Compose, `curl`, `bc`; ~4 ГБ свободной RAM.

```bash
./scripts/setup.sh      # 1. поднять стек
./scripts/run_all.sh    # 2. построить Bronze/Silver/Gold и проверить
./scripts/stats.sh      # 3. цифры для отчёта
./scripts/bench.sh      # 4. бенчмарк кодеков
```

Интерфейсы: MinIO http://localhost:9001 (minioadmin/minioadmin), Lakekeeper UI http://localhost:8181/ui,
Trino http://localhost:8080, Metabase http://localhost:3000.

## Методология

1. **Bronze** — копия нужных для Q3 колонок `customer`, `orders`, `lineitem` из `tpch.sf1` без бизнес-логики.
2. **Silver** — нормализация `mktsegment`, фильтры Q3, джойн в факт «строки заказов», расчёт `revenue_line`.
3. **Gold** — агрегат по заказу, топ-10 по выручке; результат сверен с исходным Q3.
4. **Бенчмарк** — Bronze пересоздаётся под каждым кодеком; замеряются время записи, размер файлов
   (`"table$files"`) и время Q3 (1 прогрев + 3 замера, берётся минимум и среднее).
5. **Часть 2** — schema evolution и откат из снапшота на Silver; Metabase подключён к Trino и показывает Bronze.

Обоснования всех решений — в [otchet.md](otchet.md).

## Остановка

```bash
docker compose down        # остановить
docker compose down -v     # остановить и удалить все данные
```
