FROM centos:7

LABEL name="simplifi/postgres" \
      vendor="Simplifi" \
      PostgresVersion="11" \
      PostgresFullVersion="11.2" \
      Version="7.6" \
      Release="2.3.1" \
      url="https://simpli.fi" \
      summary="PostgreSQL 11.2 (PGDG) on a Centos7 base image" \
      description="Allows multiple deployment methods for PostgreSQL, including basic single primary, streaming replication with synchronous and asynchronous replicas, and stateful sets. Includes utilities for Auditing (pgaudit), statement tracking, and Backup / Restore (pgbackrest, pg_basebackup)." \
      io.k8s.description="postgres container" \
      io.k8s.display-name="Simplifi postgres container" \
      io.openshift.expose-services="" \
      io.openshift.tags="simplifi,database"

ENV PGVERSION="11" PGDG_REPO="pgdg-centos11-11-2.noarch.rpm" BACKREST_VERSION="2.10"

RUN yum -y install https://download.postgresql.org/pub/repos/yum/${PGVERSION}/redhat/rhel-7-ppc64le/${PGDG_REPO}

RUN yum -y update && \
    yum -y install epel-release && \
    yum -y update glibc-common && \
    yum -y install bind-utils && \
    yum -y install sudo \
    gettext \
    hostname \
    procps-ng  \
    rsync \
    psmisc openssh-server openssh-clients && \
    yum -y install postgresql11-server postgresql11-contrib postgresql11 \
    pgaudit13_11 \
    pgbackrest-"${BACKREST_VERSION}" && \
    yum -y clean all

ENV PGROOT="/usr/pgsql-${PGVERSION}"

# add path settings for postgres user
# bash_profile is loaded in login, but not with exec
# bashrc to set permissions in OCP when using exec
# HOME is / in OCP
COPY conf/.bash_profile /var/lib/pgsql/
COPY conf/.bashrc /var/lib/pgsql
COPY conf/.bash_profile /
COPY conf/.bashrc /

RUN mkdir -p /opt/cpm/bin /opt/cpm/conf /pgdata /pgwal /pgconf /backup /recover /backrestrepo

RUN chown -R postgres:postgres /opt/cpm /var/lib/pgsql \
    /pgdata /pgwal /pgconf /backup /recover /backrestrepo &&  \
    chmod -R g=u /opt/cpm /var/lib/pgsql \
    /pgdata /pgwal /pgconf /backup /recover /backrestrepo

# add volumes to allow override of pg_hba.conf and postgresql.conf
# add volumes to allow backup of postgres files
# add volumes to offer a restore feature
# add volumes to allow storage of postgres WAL segment files
# add volumes to locate WAL files to recover with
# add volumes for pgbackrest to write to
VOLUME ["/sshd", "/pgconf", "/pgdata", "/pgwal", "/backup", "/recover", "/backrestrepo"]

# open up the postgres port
EXPOSE 5432

COPY bin/postgres /opt/cpm/bin
COPY bin/common /opt/cpm/bin
COPY conf/postgres /opt/cpm/conf
COPY tools/pgmonitor/exporter/postgres /opt/cpm/bin/modules

RUN chmod g=u /etc/passwd && \
    chmod g=u /etc/group

RUN mkdir /.ssh && chown 26:0 /.ssh && chmod g+rwx /.ssh

# Add postgres to "wheel" group
RUN usermod -aG wheel postgres

# Enable passwordless sudo for users under the "wheel" group
RUN sed -i.bkp -e 's/#\s%wheel.*NOPASSWD.*/%wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers

# Fix issue: 'sudo: sorry, you must have a tty to run sudo'
RUN sed -i.bkp -e 's/Defaults.*requiretty.*/# Defaults requiretty/g' /etc/sudoers

# Add postgres to the "docker" group
RUN groupadd docker && \
    usermod -aG docker postgres

ENTRYPOINT ["/opt/cpm/bin/uid_postgres.sh"]

USER 26

CMD ["/opt/cpm/bin/start.sh"]
