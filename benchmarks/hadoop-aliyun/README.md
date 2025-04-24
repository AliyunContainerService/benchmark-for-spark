# 使用 Hadoop-Aliyun 模块访问阿里云 OSS

本文对在 Spark 作业中使用 [Hadoop-Aliyun](https://hadoop.apache.org/docs/stable/hadoop-aliyun/tools/hadoop-aliyun/index.html) 模块访问阿里云 OSS 的性能进行了数据量规模为 3 TB（SF=3072）的 TPC-DS 基准测试。

## 前提条件

- 已经在本地机器安装 [Git](https://git-scm.com/)、[Docker](https://www.docker.com/)、[kubectl](https://kubernetes.io/docs/reference/kubectl/) 和 [Helm 3](https://helm.sh/) 等工具；
- 已经在本地安装并配置 ossutil，详情请参考[阿里云 OSS 命令行工具 ossutil](https://help.aliyun.com/oss/developer-reference/ossutil-1/)；
- 已经生成数据量规模为 3 TB（SF=3072）的 TPC-DS 基准测试数据集并上传至 OSS，详情请参见[生成 TPC-DS 测试数据集成](../../docs/benchmark/tpcds-data-generation.md)。

## 创建基准测试环境

1. 执行如下命令，克隆本代码仓库并切换到当前基准测试所在目录：

    ```shell
    git clone https://github.com/AliyunContainerService/benchmark-for-spark.git

    cd benchmark-for-spark/benchmarks/hadoop-aliyun
    ```

2. 修改配置文件 `terraform/alicloud/terraform.tfvars`，本文使用的配置如下：

    ```terraform
    region = "cn-beijing"

    zone_id = "cn-beijing-i"

    profile = "default"

    spark = {
      master = {
        instance_count = 1
        instance_type  = "ecs.g7.2xlarge"
      }
      worker = {
        instance_count = 6
        instance_type  = "ecs.g7.8xlarge"
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
        --version 2.1.2 \
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

3. 执行如下命令，下载 Hadoop-Aliyun 及其相关依赖 Jar 包并上传至 OSS：

    ```shell
    wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aliyun/3.3.2/hadoop-aliyun-3.3.2.jar
    wget https://repo1.maven.org/maven2/com/aliyun/oss/aliyun-sdk-oss/3.17.4/aliyun-sdk-oss-3.17.4.jar
    wget https://repo1.maven.org/maven2/org/jdom/jdom2/2.0.6.1/jdom2-2.0.6.1.jar

    ossutil cp hadoop-aliyun-3.3.2.jar oss://${OSS_BUCKET}/spark/jars/
    ossutil cp aliyun-sdk-oss-3.17.4.jar oss://${OSS_BUCKET}/spark/jars/
    ossutil cp jdom2-2.0.6.1.jar oss://${OSS_BUCKET}/spark/jars/
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

## 提交基准测试作业

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

    可以添加更多形如 `--set key=value` 的参数指定基准测试的配置，支持的配置选项请参见 [values.yaml](charts/tpcds-benchmark/values.yaml)。

3. 执行如下命令，实时查看基准测试作业状态：

    ```shell
    kubectl get -w sparkapplication tpcds-benchmark-${SCALE_FACTOR}gb
    ```

    当作业执行结束后，预期输出如下：

    ```text
    NAME                     STATUS      ATTEMPTS   START                  FINISH                 AGE
    tpcds-benchmark-3072gb   COMPLETED   1          2024-05-31T16:25:18Z   2024-05-31T23:25:47Z   12h18m
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

    ```text
    oss://spark-on-ack/spark/result/tpcds/SF=3072/
    oss://spark-on-ack/spark/result/tpcds/SF=3072/timestamp=1717172938925/
    oss://spark-on-ack/spark/result/tpcds/SF=3072/timestamp=1717172938925/_SUCCESS
    oss://spark-on-ack/spark/result/tpcds/SF=3072/timestamp=1717172938925/part-00000-09313ded-8fe6-4f72-bdd2-63d0e8117570-c000.json
    oss://spark-on-ack/spark/result/tpcds/SF=3072/timestamp=1717172938925/summary.csv/
    oss://spark-on-ack/spark/result/tpcds/SF=3072/timestamp=1717172938925/summary.csv/_SUCCESS
    oss://spark-on-ack/spark/result/tpcds/SF=3072/timestamp=1717172938925/summary.csv/part-00000-0db08f60-14e6-4866-a82a-fb8b5863d739-c000.csv
    Object Number is: 7

    0.172532(s) elapsed
    ```

2. 执行如下命令，从 OSS 下载基准测试结果至本地并保存为 `result.csv`：

    ```shell
    ossutil cp oss://spark-on-ack/spark/result/tpcds/SF=3072/timestamp=1717172938925/summary.csv/part-00000-0db08f60-14e6-4866-a82a-fb8b5863d739-c000.csv result.csv
    ```

3. 执行如下命令，查看基准测试结果：

    ```shell
    cat result.csv
    ```

    期望输出如下（已省略部分内容）：

    ```shell
    q1-v2.4,7.555827733,14.645017924,9.525067462200001,2.5904191714618894
    q10-v2.4,10.139219717,12.947744009,10.972181106399999,1.0039544386190118
    q11-v2.4,55.874544235,57.542876171,56.6287968262,0.5430662413947229
    q12-v2.4,4.579125717,5.402954092,4.9307222384,0.32301686392230966
    q13-v2.4,15.9073942,18.265080114,17.072347103000002,0.9933099727270132
    q14a-v2.4,119.177384819,129.495269281,123.5429690906,3.786778786711343
    q14b-v2.4,103.46409887899999,115.289697081,109.85192228479998,4.662932511628337
    q15-v2.4,13.842170409,17.986607644,15.4219717892,1.3734498605155039
    q16-v2.4,43.282444291,55.276480839,47.590108713199996,4.59185208768297
    q17-v2.4,14.042981717,14.980429148999999,14.637328397000001,0.3634001139334673
    q18-v2.4,28.403695799,41.949688296,32.238505677199996,4.921754787967268
    q19-v2.4,7.363309527,8.245975126,7.656795179400001,0.30514480884743084
    q2-v2.4,25.816357012,32.470428279,28.547582622199997,2.451879133915654
    q20-v2.4,6.086647,6.4193623209999995,6.273996961,0.12623830909269768
    ...
    ```

    输出结果分为五列，分别为查询名称、最短运行时间（秒）、最长运行时间（秒）、平均运行时间（秒）和标准差（秒）。本示例由于只跑了一轮查询，因此最短/最长/平均执行时间相同，标准差为 0。

## 环境清理

1. 执行如下命令，删除基准测试作业：

    ```shell
    helm uninstall tpcds-benchmark-${SCALE_FACTOR}gb
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
