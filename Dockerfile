FROM  openjdk:8-jdk
LABEL maintainer="Theo Seo"  

# Override the solr download location with e.g.:
#   docker build -t mine --build-arg SOLR_DOWNLOAD_SERVER=http://www-eu.apache.org/dist/lucene/solr .
ARG SOLR_DOWNLOAD_SERVER 
ARG SOLR_VERSION="7.5.0"

RUN apt-get update && \
  apt-get -y install lsof build-essential libmecab2 libmecab-dev && \
  rm -rf /var/lib/apt/lists/*

ENV SOLR_USER="solr" \
    SOLR_UID="8983" \
    SOLR_GROUP="solr" \
    SOLR_GID="8983" \
    #SOLR_VERSION="7.5.0" \
    SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/${SOLR_VERSION}/solr-${SOLR_VERSION}.tgz" \
    SOLR_SHA256="eac2daffc376dd8057ee831fbfc4a1b8ee236b8ad94122e11d67fd2b242acebc" \
    SOLR_KEYS="052C5B48A480B9CEA9E218A5F98C13CFA5A135D8" \
    PATH="/opt/solr/bin:/opt/docker-solr/scripts:$PATH"

ENV GOSU_VERSION 1.10
ENV GOSU_KEY B42F6819007F00F88E364FD4036A9C25BF357DD4

RUN groupadd -r --gid $SOLR_GID $SOLR_GROUP && \
  useradd -r --uid $SOLR_UID --gid $SOLR_GID $SOLR_USER

RUN set -e; \
  export GNUPGHOME="/tmp/gnupg_home" && \
  mkdir -p "$GNUPGHOME" && \
  chmod 700 "$GNUPGHOME" && \
  for key in $SOLR_KEYS $GOSU_KEY; do \
    found=''; \
    for server in \
      ha.pool.sks-keyservers.net \
      keyserver.ubuntu.com \
      hkp://keyserver.ubuntu.com:80 \
      hkp://p80.pool.sks-keyservers.net:80 \
      pgp.mit.edu \
    ; do \
      echo "  trying $server for $key"; \
      gpg --batch --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch $key from several disparate servers -- network issues?" && exit 1; \
  done; \
  exit 0

RUN set -e; \
  export GNUPGHOME="/tmp/gnupg_home" && \
  dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" && \
  wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" && \
  wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" && \
  gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
  rm /usr/local/bin/gosu.asc && \
  chmod +x /usr/local/bin/gosu && \
  gosu nobody true && \
  mkdir -p /opt/solr && \
  echo "downloading $SOLR_URL" && \
  wget -nv $SOLR_URL -O /opt/solr.tgz && \
  echo "downloading $SOLR_URL.asc" && \
  wget -nv $SOLR_URL.asc -O /opt/solr.tgz.asc && \
  echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c - && \
  (>&2 ls -l /opt/solr.tgz /opt/solr.tgz.asc) && \
  gpg --batch --verify /opt/solr.tgz.asc /opt/solr.tgz && \
  tar -C /opt/solr --extract --file /opt/solr.tgz --strip-components=1 && \
  rm /opt/solr.tgz* && \
  rm -Rf /opt/solr/docs/ && \
  mkdir -p /opt/solr/server/solr/lib /opt/solr/server/solr/mycores /opt/solr/server/logs /docker-entrypoint-initdb.d /opt/docker-solr /opt/mysolrhome && \
  sed -i -e 's/"\$(whoami)" == "root"/$(id -u) == 0/' /opt/solr/bin/solr && \
  sed -i -e 's/lsof -PniTCP:/lsof -t -PniTCP:/' /opt/solr/bin/solr && \
  sed -i -e '/-Dsolr.clustering.enabled=true/ a SOLR_OPTS="$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60"' /opt/solr/bin/solr.in.sh && \
  chown -R $SOLR_USER:$SOLR_GROUP /opt/solr /opt/mysolrhome


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

RUN cd /opt/solr/server/solr && \
    wget --quiet https://storage.googleapis.com/dbnews/dbnews.tar.gz && \
    tar -xzvf dbnews.tar.gz && \ 
    rm -f dbnews.tar.gz
RUN rm -f /opt/solr/server/solr/dbnews/data/index/write.lock

USER root
RUN cp /tmp/mecab-java-0.996/libMeCab.so /usr/local/lib && \
    rm -rf $SERVER_DIR/mecab    
COPY user-dic/* /tmp/mecab-ko-dic-2.0.1-20150920/user-dic/
RUN cd /tmp/mecab-ko-dic-2.0.1-20150920 && \
    ./tools/add-userdic.sh; make; make install
    

COPY scripts /opt/docker-solr/scripts
RUN chown -R $SOLR_USER:$SOLR_USER /opt/docker-solr

COPY conf/* /opt/solr/server/solr/configsets/data_driven_schema_configs/conf/
RUN chown -R $SOLR_USER:$SOLR_USER /opt/solr/server/solr/configsets/data_driven_schema_configs/conf

ENV PATH /opt/solr/bin:/opt/docker-solr/scripts:$PATH

EXPOSE 8983
WORKDIR /opt/solr
USER $SOLR_USER

RUN docker-entrypoint.sh

#ENTRYPOINT ["solr"]
#CMD ["start","-Djava.library.path=/usr/local/lib"]
CMD ["solr-kr"]
