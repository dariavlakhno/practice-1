#!/usr/bin/env bash
# Поднимает стек и создаёт warehouse "lakehouse" в Lakekeeper.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> 1. Поднимаем контейнеры"
docker compose up -d

echo "==> 2. Ждём Lakekeeper"
until curl -sf http://localhost:8181/health >/dev/null; do sleep 2; done
echo "Lakekeeper жив"

echo "==> 3. Bootstrap Lakekeeper (один раз)"
curl -s -o /dev/null -w "bootstrap HTTP %{http_code}\n" \
  -X POST http://localhost:8181/management/v1/bootstrap \
  -H 'Content-Type: application/json' \
  -d '{"accept-terms-of-use": true}' || true

echo "==> 4. Создаём warehouse lakehouse -> бакет MinIO lakehouse"
curl -s -w "\nwarehouse HTTP %{http_code}\n" \
  -X POST http://localhost:8181/management/v1/warehouse \
  -H 'Content-Type: application/json' \
  -d '{
    "warehouse-name": "lakehouse",
    "storage-profile": {
      "type": "s3",
      "bucket": "lakehouse",
      "endpoint": "http://minio:9000",
      "region": "local-01",
      "path-style-access": true,
      "flavor": "minio",
      "sts-enabled": false
    },
    "storage-credential": {
      "type": "s3",
      "credential-type": "access-key",
      "aws-access-key-id": "minioadmin",
      "aws-secret-access-key": "minioadmin"
    }
  }' || true

echo "==> 5. Ждём Trino"
until docker exec trino trino --execute "SELECT 1" >/dev/null 2>&1; do sleep 3; done

echo "==> 6. Проверка каталогов"
docker exec trino trino --execute "SHOW CATALOGS"
echo "Готово. Дальше: ./scripts/run_all.sh"
