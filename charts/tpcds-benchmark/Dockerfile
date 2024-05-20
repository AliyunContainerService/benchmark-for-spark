ARG SPARK_IMAGE

FROM alibaba-cloud-linux-3-registry.cn-hangzhou.cr.aliyuncs.com/alinux3/alinux3:3.9 as builder

ENV TPCDS_KIT_VERSION "master"

RUN set -eux && \
    yum update -y && \
    yum group install -y "Development Tools" && \
    git clone https://github.com/databricks/tpcds-kit.git -b ${TPCDS_KIT_VERSION} /tmp/tpcds-kit && \
    cd /tmp/tpcds-kit/tools && \
    make OS=LINUX

FROM ${SPARK_IMAGE}

COPY --from=builder /tmp/tpcds-kit/tools /opt/tpcds-kit/tools/

COPY lib/*.jar /opt/spark/jars

COPY target/scala-2.12/*.jar /opt/spark/jars/
