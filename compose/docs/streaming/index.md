---
tags:
  - example
  - streaming
  - kafka
---

<!-- TODO: MOVE TO GITHUB REPO -->
# Streaming example using Redpanda

Redpanda is a simple, powerful, and cost-efficient streaming data platform that is compatible with Kafka® APIs while eliminating Kafka complexity. To learn more about Redpanda, see [this link](https://redpanda.com/)

In the example below, we are creating ```redpanda``` as a Resource, configuring it to deploy in your customers account, and added horizontal scaling by allowing customers to change the number of nodes as needed.

!!! note
    Please don't forget to replace the account numbers, project id and other information with your own account information below

```yaml
version: '3.9'

x-omnistrate-byoa:
  awsAccountId: 'your-aws-account-id'
  awsBootstrapRoleAccountArn: 'arn:aws:iam::your-aws-account-id:role/omnistrate-bootstrap-role'

x-customer-integrations:
  logs: 
  metrics: 

networks:
  redpanda_network:
    driver: bridge

services:
  redpanda:
    image: "ghcr.io/omnistrate/demos-redpanda:v23.2.9-core"
    ports:
      - "9092:9092"
      - "8082:8082"
      - "8081:8081"
      - "9644:9644"
    x-omnistrate-mode-internal: false
    x-omnistrate-compute:
      replicaCountAPIParam: numNodes
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

    x-omnistrate-api-params:
      - key: instanceType
        description: Instance Type
        name: Instance Type
        type: String
        modifiable: true
        required: true
        export: true
        defaultValue: t4g.small
      - key: numNodes
        description: Number of Nodes
        name: Number of Nodes
        type: Float64
        modifiable: true
        required: false
        export: true
        defaultValue: "1"
    environment:
      SECURITY_CONTEXT_USER_ID: "0"
      SECURITY_CONTEXT_GROUP_ID: "0"
      SECURITY_CONTEXT_FS_GROUP: "0"
    volumes:
      - ./data:/var/lib/redpanda/data
    networks:
      - redpanda_network
```
