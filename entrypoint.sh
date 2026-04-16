#!/bin/sh
set -eu

LOG_FILE="/backup/backup.log"

mkdir -p /backup/daily /backup/weekly /backup/monthly
touch "${LOG_FILE}"

log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ENTRYPOINT] INFO: $*" >> "${LOG_FILE}"
}

log_warn() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ENTRYPOINT] WARN: $*" >> "${LOG_FILE}"
}

{
    echo "============================================================"
    echo " docker-mariadb-backup"
    echo " Startzeit: $(date '+%Y-%m-%d %H:%M:%S')"
    echo " Host: ${MARIADB_HOST:-mariadb}:${MARIADB_PORT:-3306}"
    echo " User: ${MARIADB_USER:-root}"
    echo " Prefix: ${BACKUP_PREFIX:-mariadb}"
    echo " Retention daily/weekly/monthly: ${RETENTION_DAILY:-7}/${RETENTION_WEEKLY:-4}/${RETENTION_MONTHLY:-6}"
    echo " Zeitzone: ${TZ:-Europe/Zurich}"
    echo "============================================================"
} >> "${LOG_FILE}"

if [ -z "${MARIADB_PASSWORD:-}" ]; then
    log_warn "MARIADB_PASSWORD ist nicht gesetzt. Backups werden fehlschlagen."
else
    if mariadb \
        --connect-timeout=3 \
        -h "${MARIADB_HOST:-mariadb}" \
        -P "${MARIADB_PORT:-3306}" \
        -u "${MARIADB_USER:-root}" \
        -p"${MARIADB_PASSWORD}" \
        -e "SELECT VERSION();" >/dev/null 2>&1; then
        log_info "Connectivity Pruefung erfolgreich."
    else
        log_warn "Connectivity Pruefung fehlgeschlagen. Cron startet trotzdem."
    fi
fi

log_info "Starte BusyBox crond im Vordergrund."
# BusyBox crond ist in restriktiven Runtime Profilen robuster als dcron.
exec busybox crond -f -l 8 -L "${LOG_FILE}"
