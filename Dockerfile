FROM python:3.10-slim AS build
ARG DEBIAN_FRONTEND noninteractive
ENV PATH="/root/.local/bin:$PATH"
WORKDIR /app
COPY . /app
# Install poetry
RUN set -eux; \
    apt update; \
    apt install -y --no-install-recommends curl; \
    curl -sSL https://install.python-poetry.org | python3 -; \
    poetry --version
# Build gerapy
RUN set -eux; \
    poetry install; \
    poetry build --format wheel


FROM python:3.10-slim
# Install gerapy
ARG DEBIAN_FRONTEND noninteractive
ENV GERAPY_HOME_DIR ${GERAPY_HOME_DIR:-/home/gerapy}
ENV GERAPY_GROUP ${GERAPY_GROUP:-gerapy}
ENV GERAPY_GID ${GERAPY_GID:-10000}
ENV GERAPY_USER ${GERAPY_USER:-gerapy}
ENV GERAPY_UID ${GERAPY_UID:-10000}
ENV GERAPY_PORT ${GERAPY_PORT:-8000}
WORKDIR $GERAPY_HOME_DIR
COPY --from=build /app/dist/gerapy-*.whl /tmp/
RUN \
    set -eux; \
    apt update; \
    apt install -y --no-install-recommends tini gosu; \
    pip install --no-color --disable-pip-version-check --no-cache-dir /tmp/gerapy-*.whl; \
    rm -f /tmp/gerapy-*.whl; \
    mkdir -p $GERAPY_HOME_DIR; \
    addgroup --gid $GERAPY_GID $GERAPY_GROUP; \
    adduser --uid $GERAPY_UID --home $GERAPY_HOME_DIR --ingroup $GERAPY_GROUP $GERAPY_USER; \
    chown $GERAPY_USER:$GERAPY_GROUP $GERAPY_HOME_DIR; \
    apt autoclean; \
    rm -rf /var/lib/apt/lists/*;
# Build run script
RUN \
    set -eux; \
    runscript="/usr/local/bin/gerapy-runner"; \
    echo "#!/bin/sh -ex" > $runscript; \
    echo >> $runscript; \
    echo "find \"$GERAPY_HOME_DIR\" \! -user \"$GERAPY_USER\" -exec chown $GERAPY_USER:$GERAPY_GROUP '{}' +" >> $runscript; \
    cmd="gosu $GERAPY_USER:$GERAPY_GROUP gerapy"; \
    echo "$cmd init ." >> $runscript; \
    echo "$cmd migrate" >> $runscript; \
    echo "$cmd initadmin" >> $runscript; \
    echo "$cmd runserver 0.0.0.0:$GERAPY_PORT" >> $runscript; \
    chmod +x $runscript;
VOLUME $GERAPY_HOME_DIR
EXPOSE $GERAPY_PORT
ENTRYPOINT ["tini", "--"]
CMD ["gerapy-runner"]
