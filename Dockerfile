FROM    openjdk:8-jdk
MAINTAINER  Martijn Koster "mak-docker@greenhills.co.uk"

# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER

RUN apt-get update && \
  apt-get -y install lsof build-essential libmecab2 libmecab-dev && \
  rm -rf /var/lib/apt/lists/*

ENV SOLR_USER solr
ENV SOLR_UID 8983

RUN groupadd -r -g $SOLR_UID $SOLR_USER && \
  useradd -r -u $SOLR_UID -g $SOLR_USER $SOLR_USER

ENV SOLR_VERSION 6.5.0
ENV SOLR_URL ${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/$SOLR_VERSION/solr-$SOLR_VERSION.tgz
ENV SOLR_SHA256 893835a1d724bda80bc0b9d87893a321f442460937d61d26746cefb52286543c
ENV SOLR_KEYS 052C5B48A480B9CEA9E218A5F98C13CFA5A135D8

RUN set -e; for key in $SOLR_KEYS; do \
    found=''; \
    for server in \
      ha.pool.sks-keyservers.net \
      hkp://keyserver.ubuntu.com:80 \
      hkp://p80.pool.sks-keyservers.net:80 \
      pgp.mit.edu \
    ; do \
      echo "  trying $server for $key"; \
      gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch $key from several disparate servers -- network issues?" && exit 1; \
  done; \
  exit 0

RUN mkdir -p /opt/solr && \
  wget -nv $SOLR_URL -O /opt/solr.tgz && \
  wget -nv $SOLR_URL.asc -O /opt/solr.tgz.asc && \
  echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c - && \
  (>&2 ls -l /opt/solr.tgz /opt/solr.tgz.asc) && \
  gpg --batch --verify /opt/solr.tgz.asc /opt/solr.tgz && \
  tar -C /opt/solr --extract --file /opt/solr.tgz --strip-components=1 && \
  rm /opt/solr.tgz* && \
  rm -Rf /opt/solr/docs/ && \
  mkdir -p /opt/solr/server/solr/lib /opt/solr/server/solr/mycores && \
  sed -i -e 's/#SOLR_PORT=8983/SOLR_PORT=8983/' /opt/solr/bin/solr.in.sh && \
  sed -i -e '/-Dsolr.clustering.enabled=true/ a SOLR_OPTS="$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60"' /opt/solr/bin/solr.in.sh && \
  chown -R $SOLR_USER:$SOLR_USER /opt/solr && \
  mkdir /docker-entrypoint-initdb.d /opt/docker-solr/


RUN cd /tmp && \
    wget --quiet https://bitbucket.org/eunjeon/mecab-ko/downloads/mecab-0.996-ko-0.9.2.tar.gz && \
    tar zxfv mecab-0.996-ko-0.9.2.tar.gz && \
    cd mecab-0.996-ko-0.9.2 && \
    ./configure && \
    make && \
    make check && \
    make install && \
    ldconfig

RUN cd /tmp && \
    wget --quiet https://bitbucket.org/eunjeon/mecab-ko-dic/downloads/mecab-ko-dic-2.0.1-20150920.tar.gz; \
    tar zxfv mecab-ko-dic-2.0.1-20150920.tar.gz; \
    cd mecab-ko-dic-2.0.1-20150920; \
    ./autogen.sh; \
    ./configure; make; make install; ldconfig

USER $SOLR_USER
RUN cd /tmp && \
    wget --quiet https://bitbucket.org/eunjeon/mecab-ko-lucene-analyzer/downloads/mecab-ko-lucene-analyzer-0.21.0.tar.gz && \
    tar zxvf mecab-ko-lucene-analyzer-0.21.0.tar.gz; \
    cp mecab-ko-lucene-analyzer-0.21.0/mecab-ko-mecab-loader-0.21.0.jar /opt/solr/server/lib/ext; \
    mkdir /opt/solr/contrib/eunjeon; mkdir /opt/solr/contrib/eunjeon/lib; \
    cp mecab-ko-lucene-analyzer-0.21.0/mecab-ko-lucene-analyzer-0.21.0.jar /opt/solr/contrib/eunjeon/lib    

RUN cd /tmp && \
    wget --quiet https://bitbucket.org/eunjeon/mecab-java/downloads/mecab-java-0.996.tar.gz && \
    tar zxvf mecab-java-0.996.tar.gz

COPY Makefile /tmp/mecab-java-0.996

RUN cd /tmp/mecab-java-0.996 && \
    make && \
    cp /tmp/mecab-java-0.996/MeCab.jar /opt/solr/server/lib/ext

USER root
RUN cp /tmp/mecab-java-0.996/libMeCab.so /usr/local/lib && \
    rm -rf $SERVER_DIR/mecab    

COPY scripts /opt/docker-solr/scripts
RUN chown -R $SOLR_USER:$SOLR_USER /opt/docker-solr

ENV PATH /opt/solr/bin:/opt/docker-solr/scripts:$PATH

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER
#RUN docker-entrypoint.sh

COPY conf/* /opt/solr/server/solr/configsets/data_driven_schema_configs/conf/
RUN chown -R $SOLR_USER:$SOLR_USER /opt/solr/server/solr/configsets/data_driven_schema_configs/conf
#ENTRYPOINT ["solr"]
#CMD ["start","-Djava.library.path=/usr/local/lib"]
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-kr"]
