FROM alpine:3.20

LABEL org.opencontainers.image.title="docker-mariadb-backup" \
      org.opencontainers.image.description="Wiederverwendbarer Sidecar Container fuer automatisierte MariaDB Backups" \
      org.opencontainers.image.source="https://github.com/intelitec/docker-mariadb-backup" \
      org.opencontainers.image.vendor="Intelitec AG" \
      org.opencontainers.image.licenses="MIT"

RUN apk add --no-cache \
    mariadb-client \
    dcron \
    tzdata \
    gzip \
    findutils \
    coreutils \
    curl \
    ca-certificates

ENV MARIADB_HOST=mariadb \
    MARIADB_PORT=3306 \
    MARIADB_USER=root \
    RETENTION_DAILY=7 \
    RETENTION_WEEKLY=4 \
    RETENTION_MONTHLY=6 \
    BACKUP_PREFIX=mariadb \
    TZ=Europe/Zurich

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY backup.sh /usr/local/bin/backup.sh
COPY crontab /etc/crontabs/root

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/backup.sh && \
    chmod 0600 /etc/crontabs/root && \
    mkdir -p /backup

VOLUME ["/backup"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD pgrep crond >/dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
