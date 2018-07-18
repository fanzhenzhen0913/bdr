# vim:set ft=dockerfile:
FROM debian:stretch

ENV DEBIAN_FRONTEND noninteractive
ENV PG_MAJOR 9.4
ENV LANG en_US.utf8
ENV PATH /usr/lib/postgresql/$PG_MAJOR/bin:$PATH
ENV PGDATA /var/lib/postgresql/data

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r postgres && useradd -r -g postgres postgres \
  # grab gosu for easy step-down from root
  && apt-get update && apt-get install -y curl locales gnupg \
  && gpg --keyserver pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
  && curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.2/gosu-$(dpkg --print-architecture)" \
  && curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.2/gosu-$(dpkg --print-architecture).asc" \
  && gpg --verify /usr/local/bin/gosu.asc \
  && rm /usr/local/bin/gosu.asc \
  && chmod +x /usr/local/bin/gosu \

  # make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
  && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
  && mkdir /docker-entrypoint-initdb.d \

  # Add repo gpg keys to apt
  && curl -s http://packages.2ndquadrant.com/bdr/apt/AA7A6805.asc | apt-key add - \
  && curl -s https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \

  # Add repos to list
  && echo 'deb http://packages.2ndquadrant.com/bdr/apt/ stretch-2ndquadrant main ' > /etc/apt/sources.list.d/2ndquadrant.list \
  && echo 'deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main ' > /etc/apt/sources.list.d/pgdg.list \

  # Install postgresql-bdr
  && apt-get update \
  #&& apt-get install -y postgresql-common \
  #&& sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf \
  && apt-get install -y postgresql-bdr-$PG_MAJOR-bdr-plugin \
  && apt-get purge -y --auto-remove curl \
  && rm -rf /var/lib/apt/lists/* \

  && mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

VOLUME /var/lib/postgresql/data

COPY docker-entrypoint.sh /

#stage 2 build gis ext
ENV POSTGIS_MAJOR 2.4
ENV POSTGIS_VERSION 2.4.4+dfsg-4.pgdg90+1
RUN apt-get update \
      && apt-cache showpkg postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
      && apt-get install -y --no-install-recommends \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR=$POSTGIS_VERSION \
           postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts=$POSTGIS_VERSION \
           postgis=$POSTGIS_VERSION \
      && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/postgis.sh
COPY ./update-postgis.sh /usr/local/bin
#stage 2 end

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]
