# 使用倚天 arm64 架构 ECS 实例

本文在倚天 arm64 架构 ECS 实例中对 Spark 进行了数据量规模为 3 TB（SF=3072）的 TPC-DS 基准测试。

## 前提条件

- 已经在本地机器安装 [Git](https://git-scm.com/)、[Docker](https://www.docker.com/)、[kubectl](https://kubernetes.io/docs/reference/kubectl/) 和 [Helm 3](https://helm.sh/) 等工具；
- 已经在本地安装并配置 ossutil，详情请参考[阿里云 OSS 命令行工具 ossutil](https://help.aliyun.com/oss/developer-reference/ossutil-1/)；

## 创建基准测试环境

1. 执行如下命令，克隆本代码仓库并切换到当前基准测试所在目录：

    ```shell
    git clone https://github.com/AliyunContainerService/benchmark-for-spark.git

    cd benchmark-for-spark/benchmarks/arm64
    ```

2. 修改配置文件 `terraform/alicloud/terraform.tfvars`，本文使用的配置如下：

    ```terraform
    region = "cn-beijing"

    zone_id = "cn-beijing-i"

    profile = "default"

    spark = {
      master = {
        instance_count = 1
        instance_type  = "ecs.g8y.2xlarge"
      }
      worker = {
        instance_count = 6
        instance_type  = "ecs.g8y.8xlarge"
      }
    }
    ```

    其中各个字段含义如下：

    - `region`：阿里云地域，默认为 `cn-beijing`；
    - `zone_id`：阿里云可用区，默认为 `cn-beijing-i`；
    - `profile`：阿里云配置文件，默认为 `default`；
    - `spark`：Spark 集群配置，包括 master 节点和 worker 节点的节点数量和 ECS 实例类型。

3. 执行如下命令，初始化 Terraform：

    ```shell
    terraform -chdir=terraform/alicloud init
    ```

4. 执行如下命令，创建基准测试环境：

    ```shell
    terraform -chdir=terraform/alicloud apply
    ```

    命令执行过程中需要手动输入 `yes` 进行确认。

## 部署 Spark Operator

1. 如果尙未添加阿里云容器服务 Helm chart 仓库，执行如下命令进行添加：

    ```shell
    helm repo add --force-update aliyunhub https://aliacs-app-catalog.oss-cn-hangzhou.aliyuncs.com/charts-incubator
    ```

2. 执行如下命令，部署阿里云 `ack-spark-operator` 组件：

    ```shell
    helm install spark-operator aliyunhub/ack-spark-operator \
        --version 2.1.0 \
        --namespace spark \
        --create-namespace \
        --set image.registry=registry-cn-beijing-vpc.ack.aliyuncs.com \
        --set 'spark.jobNamespaces={default}' \
        --set spark.serviceAccount.name=spark
    ```

## 准备基准测试容器镜像

本文已经提供了基准测试容器镜像，执行如下命令进行设置：

```shell
# 镜像仓库
IMAGE_REPOSITORY=kube-ai-registry.cn-shanghai.cr.aliyuncs.com/kube-ai/spark-tpcds-benchmark

# 镜像标签
IMAGE_TAG=3.3.2-0.1
```

## 准备依赖 Jar 包并上传至 OSS

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

3. 执行如下命令，下载 JindoSDK 6.4.0 版本及其相关依赖 Jar 包并上传至 OSS：

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

## 创建 PV 和 PVC

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

## 生成基准测试数据

1. 执行如下命令，设置数据生成作业参数：

    ```shell
    # 规模因子
    SCALE_FACTOR=3072

    # 分区数量
    NUM_PARTITIONS=640
    ```

2. 执行如下命令，提交数据生成作业：

    ```shell
    helm install tpcds-data-generation-${SCALE_FACTOR}gb charts/tpcds-data-generation \
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

5. 当数据生成完成之后，执行如下命令，查看生成的数据集目录结构：

    ```shell
    ossutil ls -d oss://${OSS_BUCKET}/spark/data/tpcds/${SCALE_FACTOR}gb/
    ```

    预期输出：

    ```text
    oss://example-bucket/spark/data/tpcds/3072gb/
    oss://example-bucket/spark/data/tpcds/3072gb/call_center/
    oss://example-bucket/spark/data/tpcds/3072gb/catalog_page/
    oss://example-bucket/spark/data/tpcds/3072gb/catalog_returns/
    oss://example-bucket/spark/data/tpcds/3072gb/catalog_sales/
    oss://example-bucket/spark/data/tpcds/3072gb/customer/
    oss://example-bucket/spark/data/tpcds/3072gb/customer_address/
    oss://example-bucket/spark/data/tpcds/3072gb/customer_demographics/
    oss://example-bucket/spark/data/tpcds/3072gb/date_dim/
    oss://example-bucket/spark/data/tpcds/3072gb/household_demographics/
    oss://example-bucket/spark/data/tpcds/3072gb/income_band/
    oss://example-bucket/spark/data/tpcds/3072gb/inventory/
    oss://example-bucket/spark/data/tpcds/3072gb/item/
    oss://example-bucket/spark/data/tpcds/3072gb/promotion/
    oss://example-bucket/spark/data/tpcds/3072gb/reason/
    oss://example-bucket/spark/data/tpcds/3072gb/ship_mode/
    oss://example-bucket/spark/data/tpcds/3072gb/store/
    oss://example-bucket/spark/data/tpcds/3072gb/store_returns/
    oss://example-bucket/spark/data/tpcds/3072gb/store_sales/
    oss://example-bucket/spark/data/tpcds/3072gb/time_dim/
    oss://example-bucket/spark/data/tpcds/3072gb/warehouse/
    oss://example-bucket/spark/data/tpcds/3072gb/web_page/
    oss://example-bucket/spark/data/tpcds/3072gb/web_returns/
    oss://example-bucket/spark/data/tpcds/3072gb/web_sales/
    oss://example-bucket/spark/data/tpcds/3072gb/web_site/
    Object and Directory Number is: 25

    0.446278(s) elapsed
    ```

## 提交基准测试作业

如果尚未生成基准测试数据集，则可以按照如下步骤生成测试数据集：

1. 执行如下命令，设置基准测试作业参数：

    ```shell
    # 规模因子
    SCALE_FACTOR=3072
    ```

2. 执行如下命令，提交基准测试作业：

    ```shell
    helm install tpcds-benchmark-${SCALE_FACTOR}gb charts/tpcds-benchmark \
        --set image.repository=${IMAGE_REPOSITORY} \
        --set image.tag=${IMAGE_TAG} \
        --set oss.bucket=${OSS_BUCKET} \
        --set oss.endpoint=${OSS_ENDPOINT} \
        --set benchmark.scaleFactor=${SCALE_FACTOR} \
        --set benchmark.numIterations=1
    ```

    可以添加更多形如 `--set key=value` 的参数指定基准测试的配置，支持的配置选项请参见 `charts/tpcds-benchmark/values.yaml`。

3. 执行如下命令，实时查看基准测试作业状态：

    ```shell
    kubectl get -w sparkapplication tpcds-benchmark-${SCALE_FACTOR}gb
    ```

4. 执行如下命令，实时查看 Driver Pod 日志输出：

    ```shell
    kubectl logs -f tpcds-benchmark-${SCALE_FACTOR}gb-driver
    ```

## 查看基准测试结果

1. 执行如下命令，查看基准测试输出：

    ```shell
    ossutil ls -s oss://${OSS_BUCKET}/spark/result/tpcds/${SCALE_FACTOR}gb/
    ```

    期望输出如下：

    ```shell
    oss://example-bucket/spark/result/tpcds/3072gb/
    oss://example-bucket/spark/result/tpcds/3072gb/timestamp=1716901969870/
    oss://example-bucket/spark/result/tpcds/3072gb/timestamp=1716901969870/_SUCCESS
    oss://example-bucket/spark/result/tpcds/3072gb/timestamp=1716901969870/part-00000-80c681de-ae8d-4449-b647-5e3d373edef1-c000.json
    oss://example-bucket/spark/result/tpcds/3072gb/timestamp=1716901969870/summary.csv/
    oss://example-bucket/spark/result/tpcds/3072gb/timestamp=1716901969870/summary.csv/_SUCCESS
    oss://example-bucket/spark/result/tpcds/3072gb/timestamp=1716901969870/summary.csv/part-00000-5a5d1e4a-3fe0-43a1-8248-3259af4f10a7-c000.csv
    Object Number is: 7

    0.172532(s) elapsed
    ```

2. 执行如下命令，从 OSS 下载基准测试结果至本地并保存为 `result.csv`：

    ```shell
    ossutil cp oss://example-bucket/spark/result/tpcds/3072gb/timestamp=1716901969870/summary.csv/part-00000-5a5d1e4a-3fe0-43a1-8248-3259af4f10a7-c000.csv result.csv
    ```

3. 执行如下命令，查看基准测试结果：

    ```shell
    cat result.csv
    ```

    期望输出如下（已省略部分内容）：

    ```shell
    q1-v2.4,13.169382888,13.169382888,13.169382888,0.0
    q10-v2.4,9.502788331,9.502788331,9.502788331,0.0
    q11-v2.4,57.161809588,57.161809588,57.161809588,0.0
    q12-v2.4,5.344221526999999,5.344221526999999,5.344221526999999,0.0
    q13-v2.4,16.183193874,16.183193874,16.183193874,0.0
    q14a-v2.4,121.433786224,121.433786224,121.433786224,0.0
    q14b-v2.4,112.871190193,112.871190193,112.871190193,0.0
    q15-v2.4,14.63114106,14.63114106,14.63114106,0.0
    q16-v2.4,47.082124609,47.082124609,47.082124609,0.0
    q17-v2.4,14.320191869,14.320191869,14.320191869,0.0
    q18-v2.4,30.619759895999998,30.619759895999998,30.619759895999998,0.0
    q19-v2.4,7.874492828999999,7.874492828999999,7.874492828999999,0.0
    q2-v2.4,34.106892226999996,34.106892226999996,34.106892226999996,0.0
    q20-v2.4,6.1991251609999996,6.1991251609999996,6.1991251609999996,0.0
    ...
    ```

    输出结果分为五列，分别为查询名称、最短运行时间（秒）、最长运行时间（秒）、平均运行时间（秒）和标准差（秒）。本示例由于只跑了一轮查询，因此最短/最长/平均执行时间相同，标准差为 0。

## 环境清理

1. 执行如下命令，删除基准测试作业：

    ```shell
    helm uninstall tpcds-benchmark
    ```

2. 执行如下命令，删除 PVC 资源：

    ```shell
    kubectl delete -f oss-pvc.yaml
    ```

3. 执行如下命令，删除 PV 资源：

    ```shell
    kubectl delete -f oss-pv.yaml
    ```

4. 执行如下命令，删除 Secret 资源：

    ```shell
    kubectl delete -f oss-secret.yaml
    ```

5. 如果不再需要本示例中创建的存储桶，执行如下命令，删除 OSS 存储桶：

    ```shell
    ossutil rm oss://${OSS_BUCKET} -b
    ```

    注意事项：

    - 删除 OSS 存储桶为不可逆操作，请谨慎操作，以免数据丢失。

6. 销毁基准测试集群环境：

    ```shell
    terraform -chdir=terraform/alicloud destroy
    ```

    命令执行过程中需要手动输入 `yes` 进行确认。
