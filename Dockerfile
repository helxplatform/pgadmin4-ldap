########################################################################
#
# pgAdmin 4 - PostgreSQL Tools
#
# Converted from Alpine to Ubuntu
#
#########################################################################

#########################################################################
# Create a Node container which will be used to build the JS components
# and clean up the web/ source code
#########################################################################

FROM debian:bullseye-20250407 AS app-builder

RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    bash \
    curl \
    g++ \
    git \
    libjpeg-dev \
    libpng-dev \
    libtool \
    make \
    nasm \
    zlib1g-dev && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    corepack enable && \
    corepack prepare yarn@3.6.4 --activate && \
    rm -rf /var/lib/apt/lists/*

# Copy and clean the source
COPY web /pgadmin4/web
COPY .git /pgadmin4/.git
RUN rm -rf /pgadmin4/web/*.log /pgadmin4/web/config_*.py /pgadmin4/web/node_modules

WORKDIR /pgadmin4/web
RUN yarn set version stable && \
    yarn install && \
    yarn run bundle && \
    rm -rf node_modules yarn.lock package.json


#########################################################################
# Create the base environment for Python
#########################################################################

FROM debian:bullseye-20250407 AS env-builder

COPY requirements.txt /
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    libssl-dev \
    libffi-dev \
    libpq-dev \
    libkrb5-dev \
    rustc \
    cargo \
    zlib1g-dev \
    libjpeg-dev \
    libpng-dev \
    python3-dev && \
    python3 -m venv /venv && \
    /venv/bin/pip install --upgrade pip -r requirements.txt && \
    rm -rf /var/lib/apt/lists/*

#########################################################################
# Build the documentation
#########################################################################

FROM env-builder AS docs-builder

# Install Sphinx
RUN apt-get update && apt-get install -y locales && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_US.UTF-8 && \
    /venv/bin/python3 -m pip install sphinx sphinxcontrib-youtube

# Copy the docs from the local tree. Explicitly remove any existing builds that may be present
COPY docs /pgadmin4/docs
COPY web /pgadmin4/web


# Build the docs and clean up
RUN rm -rf /pgadmin4/docs/en_US/_build && \
    LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 /venv/bin/sphinx-build /pgadmin4/docs/en_US /pgadmin4/docs/en_US/_build/html && \
    rm -rf /pgadmin4/docs/en_US/_build/html/.doctrees \
           /pgadmin4/docs/en_US/_build/html/_sources \
           /pgadmin4/docs/en_US/_build/html/_static/*.png



#########################################################################
# Create additional builders to get all of the PostgreSQL utilities
#########################################################################

FROM postgres:12 AS pg12-builder
FROM postgres:13 AS pg13-builder
FROM postgres:14 AS pg14-builder
FROM postgres:15 AS pg15-builder
FROM postgres:16 AS pg16-builder

FROM debian:bullseye-20250407 AS tool-builder

# Copy the PG binaries
COPY --from=pg12-builder /usr/bin/pg_dump /usr/local/pgsql/pgsql-12/
COPY --from=pg12-builder /usr/bin/pg_dumpall /usr/local/pgsql/pgsql-12/
COPY --from=pg12-builder /usr/bin/pg_restore /usr/local/pgsql/pgsql-12/
COPY --from=pg12-builder /usr/bin/psql /usr/local/pgsql/pgsql-12/

COPY --from=pg13-builder /usr/bin/pg_dump /usr/local/pgsql/pgsql-13/
COPY --from=pg13-builder /usr/bin/pg_dumpall /usr/local/pgsql/pgsql-13/
COPY --from=pg13-builder /usr/bin/pg_restore /usr/local/pgsql/pgsql-13/
COPY --from=pg13-builder /usr/bin/psql /usr/local/pgsql/pgsql-13/

COPY --from=pg14-builder /usr/bin/pg_dump /usr/local/pgsql/pgsql-14/
COPY --from=pg14-builder /usr/bin/pg_dumpall /usr/local/pgsql/pgsql-14/
COPY --from=pg14-builder /usr/bin/pg_restore /usr/local/pgsql/pgsql-14/
COPY --from=pg14-builder /usr/bin/psql /usr/local/pgsql/pgsql-14/

COPY --from=pg15-builder /usr/bin/pg_dump /usr/local/pgsql/pgsql-15/
COPY --from=pg15-builder /usr/bin/pg_dumpall /usr/local/pgsql/pgsql-15/
COPY --from=pg15-builder /usr/bin/pg_restore /usr/local/pgsql/pgsql-15/
COPY --from=pg15-builder /usr/bin/psql /usr/local/pgsql/pgsql-15/

COPY --from=pg16-builder /usr/bin/pg_dump /usr/local/pgsql/pgsql-16/
COPY --from=pg16-builder /usr/bin/pg_dumpall /usr/local/pgsql/pgsql-16/
COPY --from=pg16-builder /usr/bin/pg_restore /usr/local/pgsql/pgsql-16/
COPY --from=pg16-builder /usr/bin/psql /usr/local/pgsql/pgsql-16/


#########################################################################
# Final Container
#########################################################################

FROM debian:bullseye-20250407

# Environment variables
ENV PGADMIN_LISTEN_PORT=8080
ENV PGADMIN_DISABLE_POSTFIX="True"
ENV PGADMIN_CONFIG_SERVER_MODE="False"
ENV PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED="False"
ENV PGADMIN_SETUP_PASSWORD="pgadmin-setup-secret"
ENV PGADMIN_SETUP_EMAIL="user@domain.com"
ENV PGADMIN_CONFIG_UPGRADE_CHECK_ENABLED="False"

ENV PYTHONPATH=/pgadmin4/

ENV OPENSSL_FORCE_FIPS_MODE=0

RUN apt-get update && \
    apt-get install -y gnupg curl ca-certificates && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    curl -s https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y postgresql-client-15


# Copy in the tools
COPY --from=tool-builder /usr/local/pgsql /usr/local/

# Copy in psql libs (best approach):
RUN set -eux; \
    find /usr/local/pgsql -type f -executable | while read bin; do \
        ldd "$bin" | awk '{print $3}' | grep '^/' | xargs -r cp -v -t /usr/lib/; \
    done && \
    ldconfig && \
    ln -s /usr/lib/libpq.so.5 /usr/lib/libpq.so

# Copy in the startup scripts
COPY pkg/docker/run_pgadmin.py /pgadmin4/
COPY pkg/docker/gunicorn_config.py /pgadmin4/
COPY pkg/docker/entrypoint.sh /entrypoint.sh

# Config and startup files
COPY root /

# Code and docs
COPY --from=app-builder /pgadmin4/web /pgadmin4
COPY --from=docs-builder /pgadmin4/docs/en_US/_build/html/ /pgadmin4/docs

# Dependencies
COPY DEPENDENCIES /pgadmin4/DEPENDENCIES

# Install packages including LDAP
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    krb5-user \
    less \
    libcap2-bin \
    libjpeg-dev \
    libnss-ldap \
    lsb-release \
    openssl \
    python3 \
    python3-pip \
    python3-venv \
    tzdata \
    vim \
    less \
    postgresql-common

COPY --from=env-builder /venv /venv

RUN /venv/bin/pip install psycopg[binary,pool] gunicorn==20.1.0 && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/pgadmin /var/lib/pgadmin && \
    chgrp -R 0 /home /pgadmin4 /venv && \
    chmod -R g=u /home /pgadmin4 /venv && \
    chown root:root /run/pgadmin /var/lib/pgadmin && \
    chmod 1777 /run/pgadmin /var/lib/pgadmin && \
    touch /pgadmin4/config_distro.py && \
    chown root:root /pgadmin4/config_distro.py && \
    chmod 1777 /pgadmin4/config_distro.py

USER pgadmin

VOLUME /var/lib/pgadmin
EXPOSE 80 443

ENTRYPOINT ["/start.sh"]
