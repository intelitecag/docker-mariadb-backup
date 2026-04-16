# docker-mariadb-backup

[![Build Status](https://img.shields.io/github/actions/workflow/status/intelitec/docker-mariadb-backup/build.yml?branch=main)](https://github.com/intelitec/docker-mariadb-backup/actions/workflows/build.yml)
[![Lizenz](https://img.shields.io/github/license/intelitec/docker-mariadb-backup)](LICENSE)
[![GHCR Pulls](https://img.shields.io/badge/GHCR-Pulls-blue)](https://ghcr.io/intelitec/docker-mariadb-backup)

## Uebersicht

`docker-mariadb-backup` ist ein wiederverwendbarer Sidecar Container fuer automatisierte MariaDB Sicherungen. Der Container fuehrt geplante Daily, Weekly und Monthly Backups aus und speichert die komprimierten SQL Dumps getrennt nach Typ. Das Image ist auf Multiarch Betrieb ausgelegt und kann direkt aus GHCR bezogen werden.

## Features

- Automatische Backups via Cron fuer daily, weekly und monthly
- Manuelle Ausfuehrung per `docker exec` moeglich
- Komprimierte Dumps als `*.sql.gz` mit Integritaetspruefung
- Atomarer Write mit `.tmp` und `mv` gegen unvollstaendige Dateien
- Retention Policy getrennt pro Backup Typ
- Healthcheck ueber laufenden `crond` Prozess

## Quick Start

```yaml
services:
  mariadb:
    image: mariadb:11.4
    environment:
      MARIADB_ROOT_PASSWORD: supersecret

  mariadb-backup:
    image: ghcr.io/intelitec/docker-mariadb-backup:latest
    environment:
      MARIADB_HOST: mariadb
      MARIADB_USER: root
      MARIADB_PASSWORD: supersecret
    volumes:
      - ./backup:/backup
    depends_on:
      mariadb:
        condition: service_healthy
```

Ein vollstaendiges Compose Beispiel befindet sich unter `examples/docker-compose.yml`.

## Environment Variablen

| Variable | Default | Beschreibung |
|---|---|---|
| `MARIADB_HOST` | `mariadb` | Hostname der DB |
| `MARIADB_PORT` | `3306` | Port der DB |
| `MARIADB_USER` | `root` | DB User |
| `MARIADB_PASSWORD` | required | DB Passwort |
| `RETENTION_DAILY` | `7` | Anzahl Daily Backups |
| `RETENTION_WEEKLY` | `4` | Anzahl Weekly Backups |
| `RETENTION_MONTHLY` | `6` | Anzahl Monthly Backups |
| `BACKUP_PREFIX` | `mariadb` | Dateinamen Prefix |
| `TZ` | `Europe/Zurich` | Zeitzone fuer Cron |

## Backup Schedule

- daily: taeglich um 02:00
- weekly: sonntags um 02:30
- monthly: am 1. des Monats um 03:00

## Manuelles Backup

```bash
docker exec mariadb-backup /usr/local/bin/backup.sh daily
docker exec mariadb-backup /usr/local/bin/backup.sh weekly
docker exec mariadb-backup /usr/local/bin/backup.sh monthly
```

## Restore

Komplettes Restore aller Datenbanken:

```bash
gunzip -c ./backup/daily/mariadb-20260101-020000.sql.gz | docker exec -i mariadb mariadb -uroot -psupersecret
```

Einzelne Datenbank aus einem Full Dump wiederherstellen:

```bash
gunzip -c ./backup/daily/mariadb-20260101-020000.sql.gz | awk '/^-- Current Database: `appdb`/{p=1} p{print}' | docker exec -i mariadb mariadb -uroot -psupersecret appdb
```

Hinweis: Da ein `--all-databases` Dump erstellt wird, ist fuer selektives Restore oft ein vorheriger Export in eine separate Datei sinnvoll.

## Retention Strategie

Die Rotation laeuft getrennt pro Typ in den Verzeichnissen `/backup/daily`, `/backup/weekly` und `/backup/monthly`. Nach jedem Lauf bleiben nur die neuesten Dateien gemessen an Dateinamen Zeitstempel erhalten. Alles oberhalb des jeweiligen Limits wird automatisch geloescht.

## Logging

Alle Meldungen aus `entrypoint.sh`, Cron und `backup.sh` landen in `/backup/backup.log`.

## Healthcheck

Das Image enthaelt einen Docker `HEALTHCHECK`, der mit `pgrep crond` prueft, ob der Cron Daemon aktiv ist.

## Eigenes Image bauen

```bash
docker build -t docker-mariadb-backup:local .
```

Optional mit Custom Build Argumenten via Environment:

```ini
TZ=Europe/Zurich
BACKUP_PREFIX=mariadb
```

## Lizenz

Dieses Projekt steht unter der MIT Lizenz. Details siehe `LICENSE`.
