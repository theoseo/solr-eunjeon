# Solr Eunjeon
With this Dockerfile, users can use [Apache Solr 7.5](http://lucene.apache.org/solr/) with [Korean mecab analyzer](https://bitbucket.org/eunjeon/mecab-ko-lucene-analyzer)
without any special settings.

### Usage

```
git clone https://github.com/suhongs/solr-kr.git
cd solr-kr
docker build -t search --build-arg SOLR_DOWNLOAD_SERVER=https://archive.apache.org/dist/lucene/solr .
docker run -d -p 8983:8983  --name solr_server search:latest
```
