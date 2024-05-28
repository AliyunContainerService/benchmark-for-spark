ARG SPARK_IMAGE=apache/spark:v3.3.2

FROM debian:bullseye-slim as kit-builder

ENV GIT_COMMIT_ID "1b7fb7529edae091684201fab142d956d6afd881"

WORKDIR /app

RUN set -eux && \
    apt-get update && \
    apt-get install -y gcc make flex bison byacc git && \
    git clone https://github.com/databricks/tpcds-kit.git && \
    cd tpcds-kit && \
    git checkout ${GIT_COMMIT_ID} && \
    cd tools && \
    make OS=LINUX


FROM ${SPARK_IMAGE}

COPY --from=kit-builder /app/tpcds-kit/tools /opt/tpcds-kit/tools

COPY target/scala-2.12/spark-tpcds-benchmark-assembly-0.1.jar /opt/spark/jars/
