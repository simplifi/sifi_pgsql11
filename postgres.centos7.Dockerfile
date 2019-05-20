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

ENV PGVERSION="11" 
ENV PGDG_REPO="pgdg-centos11-11-2.noarch.rpm"

RUN yum -y install https://download.postgresql.org/pub/repos/yum/${PGVERSION}/redhat/rhel-7-ppc64le/${PGDG_REPO}
#RUN yum -y install https://yum.postgresql.org/11/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

RUN yum -y update \
    && yum -y install epel-release --enablerepo=extras \
    && yum -y install \ 
       glibc-common \
       bind-utils \
       sudo \
       git \
       make \
       atop \
       which \
       gettext \
       hostname \
       procps-ng  \
       rsync \
       psmisc \
       openssh-server \
       openssh-clients \
       postgresql11-server \
       postgresql11-contrib \
       postgresql11 \
       postgresql11-devel \
       pldebugger11 \
       pg_partman11 \
       pg_jobmon11 \
       pg_repack11 \
       barman \
       pgaudit13_11 \
       pgbackrest \
       postgis25_11 \
       postgis25_11-client \
       postgis25_11-devel \
       postgis25_11-utils \
       postgis25_11-docs \
       #postgis25_11-debuginfo \ INSTALLING THIS PACKAGE WILL BREAK THE CURRENT POSTGRES IMPLEMENTATION
    && yum -y clean all

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

RUN chown -R postgres:postgres /opt/cpm /var/lib/pgsql /pgdata /pgwal /pgconf /backup /recover /backrestrepo \
    && chmod -R g=u /opt/cpm /var/lib/pgsql /pgdata /pgwal /pgconf /backup /recover /backrestrepo

# add volumes to allow override of pg_hba.conf and postgresql.conf
# add volumes to allow backup of postgres files
# add volumes to offer a restore feature
# add volumes to allow storage of postgres WAL segment files
# add volumes to locate WAL files to recover with
# add volumes for pgbackrest to write to
VOLUME ["/sshd", "/pgconf", "/pgdata", "/pgwal", "/backup", "/recover", "/backrestrepo"]

COPY bin/postgres /opt/cpm/bin
COPY bin/common /opt/cpm/bin
COPY conf/postgres /opt/cpm/conf
COPY tools/pgmonitor/exporter/postgres /opt/cpm/bin/modules

RUN chmod g=u /etc/passwd \
    && chmod g=u /etc/group

RUN mkdir /.ssh && chown 26:0 /.ssh && chmod g+rwx /.ssh

# Add postgres to "wheel" group
RUN usermod -aG wheel postgres

# Enable passwordless sudo for users under the "wheel" group
RUN sed -i.bkp -e 's/#\s%wheel.*NOPASSWD.*/%wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers

# Fix issue: 'sudo: sorry, you must have a tty to run sudo'
RUN sed -i.bkp -e 's/Defaults.*requiretty.*/# Defaults requiretty/g' /etc/sudoers

# Add postgres to the "docker" group
RUN groupadd docker \
    && usermod -aG docker postgres \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

COPY sifi_custom/pg_jobmon.tar.gz /tmp
RUN cd /tmp \
    && tar zxvf pg_jobmon.tar.gz \
    && cd pg_jobmon \
    && make \
    && make install \
    && cd /tmp \
    && rm -fr pg_jobmon pg_jobmon.tar.gz

ENV LANG en_US.utf8

ENTRYPOINT ["/opt/cpm/bin/uid_postgres.sh"]

USER 26

EXPOSE 5432

CMD ["/opt/cpm/bin/start.sh"]
