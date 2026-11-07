#!/usr/bin/env bash
# Загрузка одного года в hh_lab: raw_vacancies <- CSV, затем наполнение схемы.
#   ./scripts/load_year.sh 2019
#   KEEP_RAW=1 ./scripts/load_year.sh 2019   # не очищать raw_vacancies после загрузки
# Сервер: Homebrew postgresql@16 на localhost:5433, вход без пароля (trust).
set -euo pipefail

YEAR="${1:?Укажите год, например: $0 2019}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CSV="$ROOT/data/vacancies_${YEAR}.csv"
PSQL="${PSQL:-/opt/homebrew/opt/postgresql@16/bin/psql}"
export PGHOST="${PGHOST:-localhost}" PGPORT="${PGPORT:-5433}" PGUSER="${PGUSER:-$USER}" PGDATABASE="${PGDATABASE:-hh_lab}"

[[ -f "$CSV" ]] || { echo "Нет файла $CSV" >&2; exit 1; }
run() { "$PSQL" -v ON_ERROR_STOP=1 -X "$@"; }

echo ">> staging: $CSV"
run -c "TRUNCATE raw_vacancies"
run -c "\\copy raw_vacancies FROM '$CSV' CSV HEADER"
run -Atc "SELECT 'raw rows: ' || count(*) FROM raw_vacancies"

echo ">> наполнение схемы"
run -f "$ROOT/sql/03_populate.sql"
run -f "$ROOT/sql/04_indexes.sql"

if [[ "${KEEP_RAW:-0}" != 1 ]]; then
    run -c "TRUNCATE raw_vacancies"
fi
run -Atc "SELECT 'vacancies total: ' || count(*) FROM vacancies"
