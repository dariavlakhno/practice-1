#!/usr/bin/env bash
# Поднимает стек, создаёт бакет в MinIO и warehouse "lakehouse" в Lakekeeper.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> 1. Поднимаем контейнеры (первый раз скачиваются образы, это несколько минут)"
docker compose up -d

echo "==> 2. Ждём Lakekeeper"
until curl -sf http://localhost:8181/health >/dev/null; do sleep 2; done
echo "Lakekeeper жив"

echo "==> 3. Создаём бакет lakehouse в MinIO"
# Клиент mc запускаем одноразовым контейнером в сети машины (host) (образ minio/mc удалён, берём Chainguard).
ok=0
for i in $(seq 1 30); do
  if out=$(docker run --rm --network host \
      -e MC_HOST_local=http://minioadmin:minioadmin@localhost:9000 \
      -e MC_CONFIG_DIR=/tmp/mc \
      cgr.dev/chainguard/minio-client:latest mb --ignore-existing local/lakehouse 2>&1); then
    echo "$out"; ok=1; break
  fi
  last="$out"; sleep 3
done
if [ "$ok" != 1 ]; then echo "Не удалось создать бакет. Последняя ошибка:"; echo "$last"; exit 1; fi

echo "==> 4. Bootstrap Lakekeeper (один раз)"
curl -s -o /dev/null -w "bootstrap HTTP %{http_code}\n" \
  -X POST http://localhost:8181/management/v1/bootstrap \
  -H 'Content-Type: application/json' \
  -d '{"accept-terms-of-use": true}' || true

echo "==> 5. Создаём warehouse lakehouse -> бакет MinIO lakehouse"
curl -s -w "\nwarehouse HTTP %{http_code}\n" \
  -X POST http://localhost:8181/management/v1/warehouse \
  -H 'Content-Type: application/json' \
  -d '{
    "warehouse-name": "lakehouse",
    "storage-profile": {
      "type": "s3",
      "bucket": "lakehouse",
      "endpoint": "http://localhost:9000",
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

echo "==> 6. Ждём Trino"
until docker exec trino trino --execute "SELECT 1" >/dev/null 2>&1; do sleep 3; done

echo "==> 7. Проверка каталогов"
docker exec trino trino --execute "SHOW CATALOGS"
echo "Готово. Дальше: ./scripts/run_all.sh"
