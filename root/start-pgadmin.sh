#!/bin/sh

#set -eoux pipefail

random_string () {
	env LC_CTYPE=C tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w ${1:-32} | head -n 1
}

export PGADMIN_CONFIG_DATA_DIR=${PGADMIN_CONFIG_DATA_DIR-"/home/${USER}/.helx/pgadmin"}

mkdir -p $PGADMIN_CONFIG_DATA_DIR

# Need to wipe old tabs on startup because they carry a stale app id in their URL.
PGADMIN_DB=${SQLITE_PATH:-"$PGADMIN_CONFIG_DATA_DIR/pgadmin4.db"}
if [ -f "$PGADMIN_DB" ]; then
/venv/bin/python3 - "$PGADMIN_DB" <<'EOF' || echo "start-pgadmin: could not clear saved tabs, continuing" >&2
import sqlite3
import sys

con = sqlite3.connect(sys.argv[1])
with con:
    for statement in (
        "DELETE FROM setting WHERE setting = 'Browser/Layout'"
        " OR setting LIKE 'Workspace/Layout-%'",
        "DELETE FROM application_state",
    ):
        try:
            con.execute(statement)
        except sqlite3.OperationalError as exc:
            print("start-pgadmin: %s" % exc, file=sys.stderr)
con.close()
EOF
fi

# pgAdmin wants quotes around a string variable name.
export PGADMIN_CONFIG_DATA_DIR="\"$PGADMIN_CONFIG_DATA_DIR\""

cd /pgadmin4
# Start regular entrypoint of pgadmin.
/entrypoint.sh
