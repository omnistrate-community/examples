---
tags:
  - example
  - monitoring
  - prometheus
  - byoc
  - observability
  - metrics
---

<!-- TODO: MOVE TO GITHUB REPO -->
# Prometheus BYOC example

This example shows how to deploy a Prometheus SaaS in your customers account using BYOC mode.

[![Watch the video](../../images/prometheus-demo-screenshot.png)](https://www.youtube.com/watch?v=4XG1oGdb-0k&t=747s&ab_channel=Omnistrate)

## Getting started via compose spec

To get started via compose spec, provided below we have a sample that you can use to deploy a simple instance of Prometheus.
Note that you can choose your preferred Prometheus image, in this case we are using the [prometheus-demo](https://hub.docker.com/r/omnistrate/prometheus-demo) image.

The integrations `omnistrateLogging` and `omnistrateMetrics` are activated through the `x-omnistrate-integrations`, which will send logs and metrics to your Omnistrate account and allow you to see them in the dashboard.

```yaml
version: '3.9'
x-customer-integrations:
  logs: 
  metrics: 
services:
  prometheus:
    image: docker.io/omnistrate/prometheus-demo:v1
    volumes:
      - source: ./prometheus_data
        target: /prometheus
        type: bind
        x-omnistrate-storage:
          aws:
            instanceStorageType: AWS::EBS_GP3
            instanceStorageSizeGi: 30
            instanceStorageIOPSAPIParam: instanceStorageIOPS
            instanceStorageThroughputAPIParam: instanceStorageThroughput
          gcp:
            instanceStorageType: GCP::PD_BALANCED
            instanceStorageSizeGi: 30
    environment:
      - SCRAPE_INTERVAL=10s
      - EVALUATION_INTERVAL=10s
      - TARGETS=$var.targets
      - SECURITY_CONTEXT_USER_ID=65534
      - SECURITY_CONTEXT_GROUP_ID=65534
      - SECURITY_CONTEXT_FS_GROUP=65534
    ports:
      - "9090:9090"
    x-omnistrate-capabilities:
      httpReverseProxy:
        targetPort: 9090
      enableEndpointPerReplica: true
    restart: unless-stopped
    x-omnistrate-api-params:
      - key: targets
        description: CSV of targets
        name: Targets to scrape
        type: String
        modifiable: true
        required: true
        export: true
        defaultValue: "localhost:9090"
      - key: instanceStorageIOPS
        description: Instance Storage IOPS; Applicable to AWS only
        name: Instance Storage IOPS
        type: Float64
        modifiable: true
        required: false
        export: true
        defaultValue: "3000"
      - key: instanceStorageThroughput
        description: Instance Storage Throughput (in MB /s); Applicable to AWS only
        name: Instance Storage Throughput
        type: Float64
        modifiable: true
        required: false
        export: true
        defaultValue: "125"
```

### Deploy in BYOC mode

To deploy in BYOC mode, you still need to set your provider account, you can do that as shown in the previous section, via our GUI selecting the right Deployment Model or via compose spec, by valorizing the `x-omnistrate-byoa` param in the compose spec shown below. 

Fill it with your provider account data, choose either a single cloud provider or all of the supported ones and you are all set.

```yaml
version: '3.9'
x-omnistrate-byoa:
  awsAccountId: 'your-aws-account-id'
  awsBootstrapRoleAccountArn: 'arn:aws:iam::your-aws-account-id:role/omnistrate-bootstrap-role'
x-customer-integrations:
  logs: 
  metrics: 
services:
  prometheus:
    image: docker.io/omnistrate/prometheus-demo:v1
    volumes:
      - source: ./prometheus_data
        target: /prometheus
        type: bind
        x-omnistrate-storage:
          aws:
            instanceStorageType: AWS::EBS_GP3
            instanceStorageSizeGi: 30
            instanceStorageIOPSAPIParam: instanceStorageIOPS
            instanceStorageThroughputAPIParam: instanceStorageThroughput
          gcp:
            instanceStorageType: GCP::PD_BALANCED
            instanceStorageSizeGi: 30
          azure:
            instanceStorageType: AZURE::STANDARD_SSD
            instanceStorageSizeGi: 30 
    environment:
      - SCRAPE_INTERVAL=10s
      - EVALUATION_INTERVAL=10s
      - TARGETS=$var.targets
      - SECURITY_CONTEXT_USER_ID=65534
      - SECURITY_CONTEXT_GROUP_ID=65534
      - SECURITY_CONTEXT_FS_GROUP=65534
    ports:
      - "9090:9090"
    x-omnistrate-capabilities:
      httpReverseProxy:
        targetPort: 9090
      enableEndpointPerReplica: true
    restart: unless-stopped
    x-omnistrate-api-params:
      - key: targets
        description: CSV of targets
        name: Targets to scrape
        type: String
        modifiable: true
        required: true
        export: true
        defaultValue: "localhost:9090"
      - key: instanceStorageIOPS
        description: Instance Storage IOPS; Applicable to AWS only
        name: Instance Storage IOPS
        type: Float64
        modifiable: true
        required: false
        export: true
        defaultValue: "3000"
      - key: instanceStorageThroughput
        description: Instance Storage Throughput (in MB /s); Applicable to AWS only
        name: Instance Storage Throughput
        type: Float64
        modifiable: true
        required: false
        export: true
        defaultValue: "125"
```

After that your customer can set their account by following the [BYOC guide](../../usecases/byoc.md).

To connect their account via Terraform you can show them this video [right here](https://www.youtube.com/watch?v=l6lMEZdMMxs).

In case they are using AWS we also offer a one-click setup solution for them (you can tell them that Terraform still works) here's [how it works](https://www.youtube.com/watch?v=c3HNnM8UJBE).

That's it! Now you can have your customers deploy your service in BYOC mode and distribute it for as many customers as you want.
