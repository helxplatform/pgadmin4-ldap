#!/bin/sh

#set -eoux pipefail

random_string () {
	env LC_CTYPE=C tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w ${1:-32} | head -n 1
}

export PGADMIN_CONFIG_DATA_DIR=${PGADMIN_CONFIG_DATA_DIR-"/home/${USER}/.helx/pgadmin"}

mkdir -p $PGADMIN_CONFIG_DATA_DIR

# pgAdmin wants quotes around a string variable name.
export PGADMIN_CONFIG_DATA_DIR="\"$PGADMIN_CONFIG_DATA_DIR\""

cd /pgadmin4
# Start regular entrypoint of pgadmin.
/entrypoint.sh
