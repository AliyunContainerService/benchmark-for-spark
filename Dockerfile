FROM registry.cn-hangzhou.aliyuncs.com/acs/spark:ack-2.4.5-f757ab6
RUN mkdir -p /opt/spark/jars
RUN mkdir -p /tmp/tpcds-kit
COPY ./target/scala-2.11/ack-spark-benchmark-assembly-0.1.jar /opt/spark/jars/
COPY ./lib/*.jar /opt/spark/jars/
COPY ./tpcds-kit/tools.tar.gz /tmp/tpcds-kit/
RUN cd /tmp/tpcds-kit/ && tar -xzvf tools.tar.gz