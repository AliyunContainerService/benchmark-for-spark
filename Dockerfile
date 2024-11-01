ARG SPARK_IMAGE=spark:3.5.3

ARG SBT_IMAGE=sbtscala/scala-sbt:eclipse-temurin-jammy-17.0.10_7_1.10.4_2.12.20

FROM debian:bullseye-slim AS tpcds-kit-builder

ENV GIT_COMMIT_ID=1b7fb7529edae091684201fab142d956d6afd881

WORKDIR /app

RUN set -eux && \
    apt-get update && \
    apt-get install -y gcc make flex bison byacc git

RUN set -eux && \
    git clone https://github.com/databricks/tpcds-kit.git && \
    cd tpcds-kit && \
    git checkout ${GIT_COMMIT_ID} && \
    cd tools && \
    make OS=LINUX

FROM ${SBT_IMAGE} AS benchmark-builder

WORKDIR /app

COPY . .

RUN set -eux && \
    sbt assembly

FROM ${SPARK_IMAGE}

COPY --from=tpcds-kit-builder /app/tpcds-kit/tools /opt/tpcds-kit/tools

COPY --from=benchmark-builder /app/target/scala-2.12/*.jar /opt/spark/jars/

COPY lib /opt/spark/jars/
