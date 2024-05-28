# TPC-DS 测试数据集生成

本文说明如何生成 TPC-DS 基准测试所需要用到的数据集。

## 前提条件

- 已经创建 ACK 集群；
- 已经在 ACK 集群中部署 ack-spark-operator3.0 组件，详情请参见[部署 ack-spark-operator3.0](setup-env/index.md#部署-ack-spark-operator30)；
- 已经在本地机器安装 ossutil 工具，详情请参见[安装 ossutil](https://help.aliyun.com/zh/oss/developer-reference/install-ossutil);
- 已经在本地机器安装 [Git](https://git-scm.com/)、[Docker](https://www.docker.com/)、[kubectl](https://kubernetes.io/docs/reference/kubectl/) 和 [Helm 3](https://helm.sh/) 等工具。

## 步骤一：准备基准测试容器镜像

执行如下命令，构建基准测试容器镜像并推送至镜像仓库：

```shell
IMAGE_REPOSITORY=registry.cn-beijing.aliyuncs.com/poc/spark-tpcds-benchmark
IMAGE_TAG=3.3.2-0.1

docker buildx build \
    --output=type=registry \
    --push \
    --platform=linux/amd64,linux/arm64 \
    --tag=${IMAGE_REPOSITORY}:${IMAGE_TAG} \
    --build-arg=SPARK_IMAGE=apache/spark:v3.3.2 \
    .
```

该容器镜像中包含了基准测试相关的 Jar 包，后续步骤中会将其他依赖 Jar 包上传至 OSS，并将 OSS 作为只读存储卷挂载至 Spark Pod 中。

## 步骤二：准备依赖 Jar 包并上传至 OSS

1. 执行如下命令，设置 OSS 相关配置：

    ```shell
    # OSS 存储桶所在地域
    REGION=cn-beijing

    # OSS 存储桶名称
    OSS_BUCKET=example-bucket

    # OSS 访问端点（默认使用内网访问端点）
    OSS_ENDPOINT=oss-${REGION}-internal.aliyuncs.com
    ```

2. 如果指定的 OSS 存储桶不存在，执行如下命令，创建该存储桶：

    ```shell
    ossutil mb oss://${OSS_BUCKET} --region ${REGION}
    ```

3. Spark 作业访问 OSS 数据有多种方式，本文选择使用 JindoSDK 6.4.0 版本。执行如下命令，下载 JindoSDK 相关依赖 Jar 包并上传至 OSS：

    ```shell
    wget https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/com/aliyun/jindodata/jindo-core/6.4.0/jindo-core-6.4.0.jar
    wget https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/com/aliyun/jindodata/jindo-core-linux-el7-aarch64/6.4.0/jindo-core-linux-el7-aarch64-6.4.0.jar
    wget https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/com/aliyun/jindodata/jindo-core-linux-el6-x86_64/6.4.0/jindo-core-linux-el6-x86_64-6.4.0.jar
    wget https://jindodata-binary.oss-cn-shanghai.aliyuncs.com/mvn-repo/com/aliyun/jindodata/jindo-sdk/6.4.0/jindo-sdk-6.4.0.jar

    ossutil cp jindo-core-6.4.0.jar oss://${OSS_BUCKET}/spark/jars/
    ossutil cp jindo-core-linux-el7-aarch64-6.4.0.jar oss://${OSS_BUCKET}/spark/jars/
    ossutil cp jindo-core-linux-el6-x86_64-6.4.0.jar oss://${OSS_BUCKET}/spark/jars/
    ossutil cp jindo-sdk-6.4.0.jar oss://${OSS_BUCKET}/spark/jars/
    ```

## 步骤三：创建 PV 和 PVC

1. 创建如下 Secret 清单文件并保存为 `oss-secret.yaml`：

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: oss-secret
    stringData:
      akId: <OSS_ACCESS_KEY_ID>
      akSecret: <OSS_ACCESS_KEY_SECRET>
    ```

    注意事项：

    - `<OSS_ACCESS_KEY_ID>` 和 `<OSS_ACCESS_KEY_SECRET>` 需分别替换成阿里云 AccessKey ID 和 AccessKey Secret。

2. 执行如下命令创建 Secret 资源：

    ```shell
    kubectl create -f oss-secret.yaml
    ```

3. 创建如下 PV 清单文件并保存为 `oss-pv.yaml`：

    ```yaml
    apiVersion: v1
    kind: PersistentVolume
    metadata:
      name: oss-pv
      labels:
        alicloud-pvname: oss-pv
    spec:
      capacity:
        storage: 200Gi
      accessModes:
      - ReadOnlyMany
      persistentVolumeReclaimPolicy: Retain
      csi:
        driver: ossplugin.csi.alibabacloud.com
        volumeHandle: oss-pv
        nodePublishSecretRef:
          name: oss-secret
          namespace: default
        volumeAttributes:
          bucket: <OSS_BUCKET>
          url: <OSS_ENDPOINT>
          otherOpts: "-o umask=022 -o max_stat_cache_size=0 -o allow_other"
          path: /
    ```

    注意事项：

    - `<OSS_BUCKET>` 需要替换成 OSS 存储桶名称。
    - `<OSS_ENDPOINT>` 需要替换成 OSS 访问端点，例如北京地域 OSS 内网访问端点为 `oss-cn-beijing-internal.aliyuncs.com`。

4. 执行如下命令创建 PV 资源：

    ```shell
    kubectl create -f oss-pv.yaml
    ```

5. 创建如下 PVC 清单文件并保存为 `oss-pvc.yaml`：

    ```yaml
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: oss-pvc
    spec:
      accessModes:
      - ReadOnlyMany
      resources:
        requests:
          storage: 200Gi
      selector:
        matchLabels:
          alicloud-pvname: oss-pv
    ```

6. 执行如下命令创建 PVC 资源：

    ```shell
    kubectl create -f oss-pvc.yaml
    ```

7. 执行如下命令查看 PVC 状态：

    ```shell
    kubectl get pvc oss-pvc
    ```

    预期输出：

    ```text
    NAME      STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
    oss-pvc   Bound    oss-pv   200Gi      ROX                           38s
    ```

    输出表明 PVC 已经创建并绑定成功。

## 步骤四：提交数据集生成作业

1. 执行如下命令，设置数据生成作业参数：

    ```shell
    # 规模因子
    SCALE_FACTOR=3072

    # 分区数量
    NUM_PARTITIONS=640
    ```

2. 执行如下命令，提交数据生成作业：

    ```shell
    helm install tpcds-data-generation charts/tpcds-data-generation \
        --set image.repository=${IMAGE_REPOSITORY} \
        --set image.tag=${IMAGE_TAG} \
        --set oss.bucket=${OSS_BUCKET} \
        --set oss.endpoint=${OSS_ENDPOINT} \
        --set benchmark.scaleFactor=${SCALE_FACTOR} \
        --set benchmark.numPartitions=${NUM_PARTITIONS}
    ```

3. 执行如下命令，实时查看 Spark 作业状态：

    ```shell
    kubectl get -w sparkapplication tpcds-data-generation-${SCALE_FACTOR}gb
    ```

4. 执行如下命令，实时查看 Driver 日志输出：

    ```shell
    kubectl logs -f tpcds-data-generation-${SCALE_FACTOR}gb-driver
    ```

## 步骤五：查看数据集

当作业执行完成之后，执行如下命令，查看生成的数据集目录结构：

```shell
ossutil ls -d oss://${OSS_BUCKET}/spark/data/tpcds/${SCALE_FACTOR}gb/
```

预期输出：

```text
oss://spark-on-ack/spark/data/tpcds/3072gb/
oss://spark-on-ack/spark/data/tpcds/3072gb/call_center/
oss://spark-on-ack/spark/data/tpcds/3072gb/catalog_page/
oss://spark-on-ack/spark/data/tpcds/3072gb/catalog_returns/
oss://spark-on-ack/spark/data/tpcds/3072gb/catalog_sales/
oss://spark-on-ack/spark/data/tpcds/3072gb/customer/
oss://spark-on-ack/spark/data/tpcds/3072gb/customer_address/
oss://spark-on-ack/spark/data/tpcds/3072gb/customer_demographics/
oss://spark-on-ack/spark/data/tpcds/3072gb/date_dim/
oss://spark-on-ack/spark/data/tpcds/3072gb/household_demographics/
oss://spark-on-ack/spark/data/tpcds/3072gb/income_band/
oss://spark-on-ack/spark/data/tpcds/3072gb/inventory/
oss://spark-on-ack/spark/data/tpcds/3072gb/item/
oss://spark-on-ack/spark/data/tpcds/3072gb/promotion/
oss://spark-on-ack/spark/data/tpcds/3072gb/reason/
oss://spark-on-ack/spark/data/tpcds/3072gb/ship_mode/
oss://spark-on-ack/spark/data/tpcds/3072gb/store/
oss://spark-on-ack/spark/data/tpcds/3072gb/store_returns/
oss://spark-on-ack/spark/data/tpcds/3072gb/store_sales/
oss://spark-on-ack/spark/data/tpcds/3072gb/time_dim/
oss://spark-on-ack/spark/data/tpcds/3072gb/warehouse/
oss://spark-on-ack/spark/data/tpcds/3072gb/web_page/
oss://spark-on-ack/spark/data/tpcds/3072gb/web_returns/
oss://spark-on-ack/spark/data/tpcds/3072gb/web_sales/
oss://spark-on-ack/spark/data/tpcds/3072gb/web_site/
Object and Directory Number is: 25

0.446278(s) elapsed
```
