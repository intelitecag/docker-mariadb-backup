#!/bin/sh
set -eu

if [ -z "${MARIADB_PASSWORD:-}" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [backup] WARN: MARIADB_PASSWORD ist nicht gesetzt." >&2
    exit 2
fi

TYPE="${1:-}"
BASE_DIR="/backup"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
LOG_TYPE="backup"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [${LOG_TYPE}] $*"
}

case "${TYPE}" in
    daily)
        RETENTION="${RETENTION_DAILY:-7}"
        TARGET_DIR="${BASE_DIR}/daily"
        ;;
    weekly)
        RETENTION="${RETENTION_WEEKLY:-4}"
        TARGET_DIR="${BASE_DIR}/weekly"
        ;;
    monthly)
        RETENTION="${RETENTION_MONTHLY:-6}"
        TARGET_DIR="${BASE_DIR}/monthly"
        ;;
    *)
        echo "Ungueltiger Parameter. Erlaubt: daily|weekly|monthly" >&2
        exit 1
        ;;
esac

LOG_TYPE="${TYPE}"
mkdir -p "${TARGET_DIR}"

FILE_NAME="${BACKUP_PREFIX:-mariadb}-${TIMESTAMP}.sql.gz"
FINAL_PATH="${TARGET_DIR}/${FILE_NAME}"
TMP_PATH="${FINAL_PATH}.tmp"

log "Backup gestartet."
log "Ziel: ${FINAL_PATH}"

if ! mariadb-dump \
    -h "${MARIADB_HOST:-mariadb}" \
    -P "${MARIADB_PORT:-3306}" \
    -u "${MARIADB_USER:-root}" \
    -p"${MARIADB_PASSWORD}" \
    --all-databases \
    --single-transaction \
    --quick \
    --routines \
    --triggers \
    --events \
    --master-data=2 \
    --flush-logs \
    --hex-blob \
    --default-character-set=utf8mb4 | gzip -9 > "${TMP_PATH}"; then
    rm -f "${TMP_PATH}"
    log "Dump fehlgeschlagen."
    exit 2
fi

if ! gzip -t "${TMP_PATH}"; then
    rm -f "${TMP_PATH}"
    log "Integritaetspruefung fehlgeschlagen."
    exit 3
fi

mv "${TMP_PATH}" "${FINAL_PATH}"
log "Backup erfolgreich geschrieben."

# Rotation: Neueste Dateien bleiben erhalten, aeltere werden geloescht.
FILES_TO_DELETE="$(find "${TARGET_DIR}" -maxdepth 1 -type f -name '*.sql.gz' | sort -r | tail -n +"$((RETENTION + 1))" || true)"
if [ -n "${FILES_TO_DELETE}" ]; then
    echo "${FILES_TO_DELETE}" | while IFS= read -r old_file; do
        [ -n "${old_file}" ] || continue
        log "Loesche altes Backup: ${old_file}"
        rm -f "${old_file}"
    done
fi

BACKUP_COUNT="$(find "${TARGET_DIR}" -maxdepth 1 -type f -name '*.sql.gz' | wc -l | tr -d ' ')"
TOTAL_SIZE="$(du -sh "${TARGET_DIR}" | awk '{print $1}')"
log "Statistik: Anzahl=${BACKUP_COUNT}, Groesse=${TOTAL_SIZE}"
log "Backup abgeschlossen."

exit 0
