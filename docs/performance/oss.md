在运行Spark任务时，用户数据经常会存放在OSS上，针对一些多Executor、小文件场景，可通过以下配置来优化性能:
```yaml
fs.oss.paging.maximum: 1000
fs.oss.multipart.download.threads: 32
fs.oss.max.total.tasks: 256
fs.oss.connection.maximum: 2048
```
更多配置可参考[hadoop-aliyun](https://hadoop.apache.org/docs/stable/hadoop-aliyun/tools/hadoop-aliyun/index.html)