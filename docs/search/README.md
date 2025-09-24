# Search example using OpenSearch

OpenSearch is the flexible, scalable, open-source way to build solutions for data-intensive applications. To learn more about OpenSearch, see [this link](https://opensearch.org/)

In the example below, we are creating ```opensearch-cluster``` as a Resource, configuring it to deploy in your account, and added horizontal scaling by allowing customers to change the number of nodes as needed. Note that this component is marked as internal and all the API params are exposed through ```opensearch dashboard``` Resource.

In addition, we have also defined ```opensearch dashboard``` as an external Resource that depends on ```opensearch-cluster``` component. Omnistrate will automatically manage the lifecycle of dependent resource based on the ```opensearch dashboard``` resource across different operations, for ex- provisioning, scaling, recovery, patching.

```opensearch dashboard``` Resource is configured to run a dashboard image to allow for a web portal access.

!!! note
    Please don't forget to replace the account numbers, project id and other information with your own account information below

```yaml
version: "3.9"

x-omnistrate-my-account:
  awsAccountId: 'xxxxxxxxxxx'   # random account number
  awsBootstrapRoleAccountArn: 'arn:aws:iam::xxxxxxxxxxx:role/omnistrate-bootstrap-role'
  gcpProjectId: 'xxxxxxxxxxx'
  gcpProjectNumber: 'xxxxxxxxxxx3'   # random account number
  gcpServiceAccountEmail: 'bootstrap.service@gcp.test.iam'
  azureSubscriptionId: 'xxxxxxxx-xxxx-xxx-xxxx-xxxxxxxxxx'
  azureTenantId: 'xxxxxxxx-xxxx-xxx-xxxx-xxxxxxxxxx'

x-customer-integrations:
  logs: 
  metrics: 

services:
  opensearch-cluster:
    x-omnistrate-mode-internal: true
    x-omnistrate-compute:
      replicaCountAPIParam: numReplicas
      instanceTypes:
        - cloudProvider: aws
          apiParam: instanceType
        - cloudProvider: gcp
          apiParam: instanceType
        - cloudProvider: azure
          apiParam: instanceType          
    x-omnistrate-capabilities:
      enableMultiZone: true
      enableEndpointPerReplica: true
    image: opensearchproject/opensearch:latest
    environment:
      - cluster.name=$var.clusterName
      - node.name=$sys.compute.node.name
      - discovery.seed_hosts=$sys.compute.nodes[*].name
      - cluster.initial_cluster_manager_nodes=$sys.compute.nodes[*].name
      - bootstrap.memory_lock=true
    volumes:
      - source: ./data
        target: /usr/share/opensearch/data
        type: bind
        x-omnistrate-storage:
          aws:
            instanceStorageType: AWS::EBS_GP3
            instanceStorageSizeGiAPIParam: instanceStorageSizeGi
            instanceStorageIOPSAPIParam: instanceStorageIOPS
            instanceStorageThroughputAPIParam: instanceStorageThroughput
          gcp:
            instanceStorageType: GCP::PD_BALANCED
            instanceStorageSizeGiAPIParam: instanceStorageSizeGi
          azure:
            instanceStorageType: AZURE::STANDARD_SSD
            instanceStorageSizeGiAPIParam: instanceStorageSizeGi
    ports:
      - '9200:9200'
    x-omnistrate-api-params:
      - key: instanceType
        description: Instance Type
        name: Instance Type
        type: String
        modifiable: true
        required: true
        export: true
      - key: instanceStorageIOPS
        description: Instance Storage IOPS
        name: Instance Storage IOPS (AWS Only)
        type: Float64
        modifiable: true
        required: true
        export: true
      - key: instanceStorageThroughput
        description: Instance Storage Throughput
        name: Instance Storage Throughput (AWS Only)
        type: Float64
        modifiable: true
        required: true
        export: true
      - key: instanceStorageSizeGi
        description: Instance Storage Size
        name: Instance Storage Size (GiB)
        type: Float64
        modifiable: true
        required: true
        export: true
      - key: clusterName
        description: Cluster Name
        name: Cluster Name
        type: String
        modifiable: true
        required: true
        export: true
      - key: numReplicas
        description: Number of Replicas
        name: Number of Replicas
        type: Float64
        modifiable: true
        required: true
        export: true

  opensearch:
    x-omnistrate-mode-internal: false
    image: opensearchproject/opensearch-dashboards:latest
    ports:
      - '5601:5601'
    environment:
      - OPENSEARCH_HOSTS=https://{{ $opensearch-cluster.sys.network.externalClusterEndpoint }}:9200
    x-omnistrate-compute:
      instanceTypes:
        - name: t4g.small
          cloudProvider: aws
        - name: e2-medium
          cloudProvider: gcp
        - name: Standard_D2s_v3
          cloudProvider: azure  
    depends_on:
      - opensearch-cluster
    x-omnistrate-capabilities:
      autoscaling:
        minReplicas: 1
        maxReplicas: 10
      httpReverseProxy:
        targetPort: 5601
      enableMultiZone: true
      enableEndpointPerReplica: false
    x-omnistrate-api-params:
      - key: instanceType
        description: Instance Type
        name: Instance Type
        type: String
        modifiable: true
        required: false
        export: true
        defaultValue: t4g.large
        parameterDependencyMap:
          opensearch-cluster: instanceType
      - key: clusterName
        description: Cluster Name
        name: Cluster Name
        type: String
        modifiable: true
        required: true
        export: true
        parameterDependencyMap:
          opensearch-cluster: clusterName
      - key: numReplicas
        description: Number of Replicas
        name: Number of Replicas
        type: Float64
        modifiable: true
        required: false
        export: true
        defaultValue: "1"
        limits:
          min: 1
          max: 10
        parameterDependencyMap:
          opensearch-cluster: numReplicas
      - key: instanceStorageIOPS
        description: Instance Storage IOPS
        name: Instance Storage IOPS (AWS Only)
        type: Float64
        modifiable: true
        required: false
        export: true
        defaultValue: "3000"
        parameterDependencyMap:
          opensearch-cluster: instanceStorageIOPS
      - key: instanceStorageThroughput
        description: Instance Storage Throughput
        name: Instance Storage Throughput (AWS Only)
        type: Float64
        modifiable: true
        required: false
        export: true
        defaultValue: "125"
        parameterDependencyMap:
          opensearch-cluster: instanceStorageThroughput
      - key: instanceStorageSizeGi
        description: Instance Storage Size
        name: Instance Storage Size (GiB)
        type: Float64
        modifiable: true
        required: false
        export: true
        defaultValue: "30"
        parameterDependencyMap:
          opensearch-cluster: instanceStorageSizeGi
```
