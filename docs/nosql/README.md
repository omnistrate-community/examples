---
tags:
  - example
  - database
  - nosql
  - compose
---

<!-- TODO: MOVE TO GITHUB REPO -->
# NoSQL example using MongoDB

MongoDB is a well known NoSQL technology with SSPL license. To learn more about MongoDB, see [this link](https://github.com/mongodb/mongo)

In the example below, we are creating ```mongodb-primary``` as a Resource, configuring it to deploy in your account, and added horizontal scaling by allowing customers to change the number of nodes as needed. Note that this component is marked as internal and all the API params are exposed through ```Cluster``` Resource.

In addition, we have defined different action hooks to run custom code on cluster creation, adding a node, removing a node, upgrading the cluster. 

Finally, we have also defined ```Cluster``` as an external Resource that depends on ```mongodb-primary``` component. Omnistrate will automatically manage the lifecycle of dependent resource based on the ```Cluster``` resource across different operations, for ex- provisioning, scaling, recovery, patching.

!!! note
    Please don't forget to replace the account numbers, project id and other information with your own account information below

```yaml
version: "3"

x-omnistrate-service-plan:
  name: 'MongoDB Service'
  tenancyType: 'OMNISTRATE_DEDICATED_TENANCY'
  deployment:
    hostedDeployment:
      awsAccountId: 'xxxxxxxxxxx'
      awsBootstrapRoleAccountArn: 'arn:aws:iam::xxxxxxxxxxx:role/omnistrate-bootstrap-role'
      gcpProjectId: 'test-account'
      gcpProjectNumber: 'xxxxxxxxxxx3'
      gcpServiceAccountEmail: 'bootstrap.service@gcp.test.iam'
      azureSubscriptionId: 'xxxxxxxx-xxxx-xxx-xxxx-xxxxxxxxxx'
      azureTenantId: 'xxxxxxxx-xxxx-xxx-xxxx-xxxxxxxxxx'

x-customer-integrations:
  logs: 
  metrics: 

services:
  mongodb-primary:
    x-omnistrate-mode-internal: true
    image: docker.io/omnistrate/mongodb:6.0-3
    ports:
      - 27017:27017
    environment:
      - SECURITY_CONTEXT_USER_ID=999
      - SECURITY_CONTEXT_GROUP_ID=999
      - SECURITY_CONTEXT_FS_GROUP=999
      - MONGO_INITDB_ROOT_USERNAME=$var.mongodbUsername
      - MONGO_INITDB_ROOT_PASSWORD=$var.mongodbPassword
      - REPLICA_SET_KEY=$var.mongodbReplicaSetKey
      - REPLICA_SET_NAME=$var.mongodbReplicaSetName
    x-omnistrate-actionhooks:
      - scope: CLUSTER
        type: INIT
        commandTemplate: |
          mongosh "mongodb://{{ $var.mongodbUsername }}:{{ $var.mongodbPassword }}@{{ $sys.compute.nodes[0].name }}:27017/?authMechanism=DEFAULT" --eval "rs.initiate()"
      - scope: NODE
        type: ADD
        commandTemplate: |
          #!/bin/bash
          set -ex

          # Check if NODE_NAME is not equal to 'mongodb-primary-0'
          if [ "$NODE_NAME" != {{ $sys.compute.nodes[0].name }} ]; then
              # Run the mongosh command
              mongosh "mongodb://{{ $var.mongodbUsername }}:{{ $var.mongodbPassword }}@{{ $sys.compute.nodes[0].name }}:27017/?authMechanism=DEFAULT" --eval "rs.add( { host: '{{ $sys.compute.node.name }}' } )"
          fi
      - scope: NODE
        type: REMOVE
        commandTemplate: |
          #!/bin/bash

          set -ex

          # Check if NODE_NAME is not equal to 'mongodb-primary-0'
          if [ "$NODE_NAME" != {{ $sys.compute.nodes[0].name }} ]; then
              # Run the mongosh command
              mongosh "mongodb://{{ $var.mongodbUsername }}:{{ $var.mongodbPassword }}@{{ $sys.compute.nodes[0].name }}:27017/?authMechanism=DEFAULT" --eval "rs.remove('{{ $sys.compute.node.name }}')"
          fi
      - scope: CLUSTER
        type: POST_UPGRADE
        commandTemplate: |
          #!/bin/bash
          
          set -ex
          
          # Connect to MongoDB and get replica set status
          mongosh "mongodb://{{ $var.mongodbUsername }}:{{ $var.mongodbPassword }}@{{ $sys.compute.nodes[0].name }}:27017/?authMechanism=DEFAULT" --eval "rs.status()" > replica_status.txt
          
          # Parse the output to find the primary
          # This is a basic example and might need adjustment based on actual output format
          NUM_PRIMARY=$(grep -o '"stateStr" *: *"PRIMARY"' replica_status.txt | wc -l)

          # Check the number of primaries
          if [[ $NUM_PRIMARY -eq 1 ]]; then
              echo "Replica set is correctly configured with one primary."
          else
              echo "Replica set configuration issue: Expected 1 primary, found $NUM_PRIMARY."
          fi
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
    volumes:
      - source: ./mongodb_master_data
        target: /data/db
        type: bind
        x-omnistrate-storage:
          aws:
            instanceStorageType: AWS::EBS_GP3
            instanceStorageSizeGi: 100
            instanceStorageIOPSAPIParam: instanceStorageIOPS
            instanceStorageThroughputAPIParam: instanceStorageThroughput
          gcp:
            instanceStorageType: GCP::PD_BALANCED
            instanceStorageSizeGi: 100
          azure:
            instanceStorageType: AZURE::PREMIUM_SSD
            instanceStorageSizeGi: 100
    x-omnistrate-api-params:
      - key: instanceType
        description: Instance Type
        name: Instance Type
        type: String
        modifiable: true
        required: true
        export: true
      - key: mongodbPassword
        description: Default DB Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
      - key: mongodbUsername
        description: Default DB Username
        name: Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: mongodbReplicaSetKey
        description: Replica Set Key
        name: Replica Set Key
        type: String
        modifiable: false
        required: true
        export: true
      - key: mongodbReplicaSetName
        description: Replica Set Name
        name: Replica Set Name
        type: String
        modifiable: false
        required: true
        export: true
      - key: instanceStorageIOPS
        description: Instance Storage IOPS; Applicable to AWS only
        name: Instance Storage IOPS
        type: Float64
        modifiable: true
        required: true
        export: true
      - key: instanceStorageThroughput
        description: Instance Storage Throughput (in MB /s); Applicable to AWS only
        name: Instance Storage Throughput
        type: Float64
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

  Cluster:
    x-omnistrate-mode-internal: false
    image: omnistrate/noop
    x-omnistrate-api-params:
      - key: instanceType
        description: Instance Type
        name: Instance Type
        type: String
        modifiable: true
        required: true
        export: true
        defaultValue: t4g.small
        parameterDependencyMap:
          mongodb-primary: instanceType
      - key: mongodbPassword
        description: Default DB Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
        parameterDependencyMap:
          mongodb-primary: mongodbPassword
      - key: mongodbUsername
        description: Default DB Username
        name: Username
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          mongodb-primary: mongodbUsername
      - key: mongodbReplicaSetKey
        description: Replica Set Key
        name: Replica Set Key
        type: String
        modifiable: false
        required: true
        export: false
        parameterDependencyMap:
          mongodb-primary: mongodbReplicaSetKey
      - key: mongodbReplicaSetName
        description: Replica Set Name
        name: Replica Set Name
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          mongodb-primary: mongodbReplicaSetName
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
          mongodb-primary: numReplicas
      - key: instanceStorageIOPS
        description: Instance Storage IOPS; Applicable to AWS only
        name: Instance Storage IOPS
        type: Float64
        modifiable: true
        required: false
        export: true
        defaultValue: "3000"
        parameterDependencyMap:
          mongodb-primary: instanceStorageIOPS
      - key: instanceStorageThroughput
        description: Instance Storage Throughput (in MB /s); Applicable to AWS only
        name: Instance Storage Throughput
        type: Float64
        modifiable: true
        required: false
        export: true
        defaultValue: "125"
        parameterDependencyMap:
          mongodb-primary: instanceStorageThroughput
    depends_on:
      - mongodb-primary
```
