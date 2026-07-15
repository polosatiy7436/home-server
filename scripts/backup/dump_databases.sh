#!/bin/bash
# dump_databases.sh — dump every containerized DB to /home/pi/Storage/backups/db/
# Credentials are read inside each container (secrets/env), nothing hardcoded here.
# Called by restic_backup.sh before the off-site snapshot; safe to run standalone.

DUMP_DIR="/home/pi/Storage/backups/db"
mkdir -p "$DUMP_DIR"
FAILED=0

dump_postgres() { # <container> <user-secret-file>
  local name=$1 user_file=$2
  echo "🗄️ Dumping postgres: $name"
  if docker exec "$name" sh -c "pg_dumpall -U \"\$(cat $user_file)\"" > "$DUMP_DIR/$name.sql.tmp"; then
    mv "$DUMP_DIR/$name.sql.tmp" "$DUMP_DIR/$name.sql"
  else
    echo "❌ Dump FAILED: $name"; rm -f "$DUMP_DIR/$name.sql.tmp"; FAILED=1
  fi
}

dump_mariadb() { # <container> <root-password-shell-snippet>
  local name=$1 pass_snippet=$2
  echo "🗄️ Dumping mariadb: $name"
  if docker exec "$name" sh -c "mariadb-dump --all-databases -uroot -p\"\$($pass_snippet)\"" > "$DUMP_DIR/$name.sql.tmp"; then
    mv "$DUMP_DIR/$name.sql.tmp" "$DUMP_DIR/$name.sql"
  else
    echo "❌ Dump FAILED: $name"; rm -f "$DUMP_DIR/$name.sql.tmp"; FAILED=1
  fi
}

dump_sqlite() { # <name> <db-path>  (consistent copy via sqlite online backup API)
  local name=$1 db=$2
  echo "🗄️ Dumping sqlite: $name"
  if python3 - "$db" "$DUMP_DIR/$name.sqlite3.tmp" <<'PY'
import sqlite3, sys
src = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
dst = sqlite3.connect(sys.argv[2])
src.backup(dst)
dst.close(); src.close()
PY
  then
    mv "$DUMP_DIR/$name.sqlite3.tmp" "$DUMP_DIR/$name.sqlite3"
  else
    echo "❌ Dump FAILED: $name"; rm -f "$DUMP_DIR/$name.sqlite3.tmp"; FAILED=1
  fi
}

dump_postgres immich_postgres    /run/secrets/IMMICH_DB_USER
dump_postgres nextcloud_postgres /run/secrets/NEXTCLOUD_DB_USER
dump_postgres mealie_postgres    /run/secrets/MEALIE_POSTGRES_USER
dump_mariadb  bookstack_db       'cat "$MYSQL_ROOT_PASSWORD_FILE"'
dump_mariadb  nginx_proxy_db     'cat "$MYSQL_ROOT_PASSWORD_FILE"'
dump_sqlite   vaultwarden        /home/pi/apps/vaultwarden/data/db.sqlite3

ls -lh "$DUMP_DIR"/*.sql "$DUMP_DIR"/*.sqlite3 2>/dev/null
[ "$FAILED" -eq 0 ] && echo "✅ All database dumps completed: $(date)" || { echo "❌ One or more dumps failed"; exit 1; }
