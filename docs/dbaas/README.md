---
tags:
  - example
  - database
  - postgresql
  - vector
  - serverless
  - compose
  - replicas
---

<!-- TODO: MOVE TO GITHUB REPO -->
# Vector database example using PostgreSQL

In this example exercise, we will build PostgreSQL SaaS with pgvector extension. Let's start simple and we will extend the offering incrementally:

## Hello world PostgreSQL SaaS

Here is a hello world version of PostgreSQL:

```yaml
version: "3"
services:
 Database:
    image: 'bitnami/postgresql:latest'
    ports:
      - 5432:5432
    volumes:
      - ./data:/var/lib/postgresql/data
    environment:
      - POSTGRESQL_PASSWORD=abc123
      - POSTGRESQL_DATABASE=testdb
      - POSTGRESQL_USERNAME=root
      - POSTGRESQL_POSTGRES_PASSWORD=rootpassword12345
      - POSTGRESQL_PGAUDIT_LOG=READ,WRITE
      - POSTGRESQL_LOG_HOSTNAME=true
      - POSTGRESQL_REPLICATION_MODE=master
      - POSTGRESQL_REPLICATION_USER=repl_user
      - POSTGRESQL_REPLICATION_PASSWORD=repl_password
      - POSTGRESQL_DATA_DIR=/var/lib/postgresql/data/dbdata
      - SECURITY_CONTEXT_USER_ID=1001
      - SECURITY_CONTEXT_FS_GROUP=1001
      - SECURITY_CONTEXT_GROUP_ID=0
```

Let's identify some of the challenges in the above setup:

- Choose the cloud provider account to host dataplane (i.e. customer databases)
- Missing metrics and logging support
- Missing metering support
- Single master postgres i.e. no support for replicas
- Missing pgvector extension
- Allow your customers to customize their database instance
- Missing cloud-native capabilities like multi zone, endpoint per replica, autoscaling based on custom metrics etc

Now, let's address each of the above gaps to achieve the desired outcome.

### Host application (database) in your own account

Add the following to the compose specification to deploy it in your account:

```yaml
x-omnistrate-service-plan:
  name: 'PostgreSQL Service'
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
```

!!! note
    Please don't forget to replace the account numbers, project id and other information with your own account information

To learn more about deploying in your customers account, see [this page](../../spec-guides/compose-spec.md).

You can also enable both and that will build separate Plans that your customers can choose between. As an example, startups segment maybe okay deploying in your account but bigger enterprises prefer to deploy your SaaS in their account.

### Metrics and logging support

Add the following to the compose spec:

```yaml
x-customer-integrations:
  logs: 
  metrics: 
```

To learn more about metrics/logging integrations, please see [this page](../../build-guides/integrations.md#metrics)

### Summary so far

Here is how PostgreSQL SaaS in your account w/ integrations looks like so far:

```yaml
version: "3"

x-omnistrate-service-plan:
  name: 'PostgreSQL Service'
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
 Database:
    image: 'bitnami/postgresql:latest'
    ports:
      - 5432:5432
    volumes:
      - ./data:/var/lib/postgresql/data
    environment:
      - POSTGRESQL_PASSWORD=abc123
      - POSTGRESQL_DATABASE=testdb
      - POSTGRESQL_USERNAME=root
      - POSTGRESQL_POSTGRES_PASSWORD=rootpassword12345
      - POSTGRESQL_PGAUDIT_LOG=READ,WRITE
      - POSTGRESQL_LOG_HOSTNAME=true
      - POSTGRESQL_REPLICATION_MODE=master
      - POSTGRESQL_REPLICATION_USER=repl_user
      - POSTGRESQL_REPLICATION_PASSWORD=repl_password
      - POSTGRESQL_DATA_DIR=/var/lib/postgresql/data/dbdata
      - SECURITY_CONTEXT_USER_ID=1001
      - SECURITY_CONTEXT_FS_GROUP=1001
      - SECURITY_CONTEXT_GROUP_ID=0
```

### Add replicas support

To add the replica support, we need to:

- Add a replica Resource to configure master and replica resources separately. Note that their configuration are different even though they both run the same base image.
- Add numReadReplicas API parameter and configure replicaCountAPIParam compute infrastructure setting with that parameter. This change will allow us to launch number of replicas based on the numReadReplicas value provided by your customers.

```yaml
services:
  Replica:
    .....
    x-omnistrate-compute:
      replicaCountAPIParam: numReadReplicas
    x-omnistrate-api-params:
      - key: numReadReplicas
        description: Number of Read Replicas
        name: Number of Read Replicas
        type: Float64
        modifiable: true
        required: true
        export: true
```

To learn more about API parameters, please see [this page](../../build-guides/api-params.md)

<br/>

To learn more about Resource dependencies, please see [this page](../../build-guides/dependencies.md)

### Enable pgvector extension

To enable pgvector extension, we will take advantage of custom code injection through action hooks.

```yaml
x-omnistrate-actionhooks:
  - scope: CLUSTER
    type: INIT
    commandTemplate: >
      PGPASSWORD=rootpassword12345 psql -U postgres
      -h master testdb -c "create extension vector"
```

To learn more about action hooks, please see [this page](../../build-guides/actionhooks.md)

### Add customization for your customers

To enable customization, we will take advantange of API parameters to configure different PostgreSQL and infrastructure settings.

As an example, let's say we want our users to specify the Master instance type:

```yaml
x-omnistrate-api-params:
  - key: masterInstanceType
    description: Master Instance Type
    name: Master Instance Type
    type: String
    modifiable: true
    required: true
    export: true
```

To learn more about SaaS configuration, please see [this page](../../build-guides/api-params.md)

### Add SaaS capabilities

To add SaaS capabilities mentioned above:

```yaml
x-omnistrate-capabilities:
  enableMultiZone: true
  enableEndpointPerReplica: true
  autoscaling:
    maxReplicas: 5
    minReplicas: 1
    idleMinutesBeforeScalingDown: 2
    idleThreshold: 20
    overUtilizedMinutesBeforeScalingUp: 3
    overUtilizedThreshold: 80
  serverlessConfiguration:
    targetPort: 5432
    enableAutoStop: true
    minimumNodesInPool: 5
```

For full list of capabilities, see [this page](../../runtime-guides/overview.md)
To learn more on serverless, please refer to the guide [here](../../runtime-guides/serverless.md)

## VectorDB Serverless SaaS

Here is the final VectorDB SaaS that one can use to generate the initial SaaS:

```yaml
version: "3"

x-omnistrate-service-plan:
  name: 'VectorDB Service'
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
  Master:
    image: 'omnistrate/pgvector:c227409'
    ports:
      - 5432:5432
    volumes:
      - ./data:/var/lib/postgresql/data
    x-omnistrate-storage:
      aws:
        instanceStorageType: AWS::EBS_GP3
        instanceStorageSizeGi: 100
        instanceStorageIOPSAPIParam: 3000
        instanceStorageThroughputAPIParam: 125
      gcp:
        instanceStorageType: GCP::PD_BALANCED
        instanceStorageSizeGi: 100
    x-omnistrate-compute:
      instanceTypes:
        - cloudProvider: aws
          apiParam: masterInstanceType
        - cloudProvider: gcp
          apiParam: masterInstanceType
    x-omnistrate-capabilities:
      autoscaling:
        maxReplicas: 1
        minReplicas: 1
        idleMinutesBeforeScalingDown: 2
        idleThreshold: 20
        overUtilizedMinutesBeforeScalingUp: 3
        overUtilizedThreshold: 80
      serverlessConfiguration:
        targetPort: 5432
        enableAutoStop: true
        minimumNodesInPool: 5
    environment:
      - POSTGRESQL_PASSWORD=$parameterGroup.var.postgresqlPassword
      - POSTGRESQL_DATABASE=$parameterGroup.var.postgresqlDatabase
      - POSTGRESQL_USERNAME=$parameterGroup.var.postgresqlUsername
      - POSTGRESQL_POSTGRES_PASSWORD=$parameterGroup.var.postgresqlRootPassword
      - POSTGRESQL_PGAUDIT_LOG=READ,WRITE
      - POSTGRESQL_LOG_HOSTNAME=true
      - POSTGRESQL_REPLICATION_MODE=master
      - POSTGRESQL_REPLICATION_USER=$parameterGroup.var.replUsername
      - POSTGRESQL_REPLICATION_PASSWORD=$parameterGroup.var.replPassword
      - POSTGRESQL_DATA_DIR=/var/lib/postgresql/data/dbdata
      - DATA_SOURCE_NAME=postgresql://{{ $parameterGroup.var.postgresqlUsername }}:{{ $parameterGroup.var.postgresqlPassword }}@localhost:5432/{{ $parameterGroup.var.postgresqlDatabase }}?sslmode=disable
      - SECURITY_CONTEXT_USER_ID=1001
      - SECURITY_CONTEXT_FS_GROUP=1001
      - SECURITY_CONTEXT_GROUP_ID=0
    x-omnistrate-api-params:
      - key: masterInstanceType
        description: Master Instance Type
        name: Master Instance Type
        type: String
        modifiable: true
        required: true
        export: true
      - key: parameterGroupId
        description: Replica configuration 
        name: Parameter Group Id
        dependentResourceKey: ParameterGroup
        type: Resource
        modifiable: true
        required: true
        export: true
    x-omnistrate-actionhooks:
      - scope: CLUSTER
        type: INIT
        commandTemplate: >
          PGPASSWORD={{ $parameterGroup.var.postgresqlRootPassword }} psql -U postgres
          -h master {{ $parameterGroup.var.postgresqlDatabase }} -c "create extension vector"

  Replica:
    image: 'omnistrate/pgvector:c227409'
    ports:
      - 5433:5432
    volumes:
      - ./data:/var/lib/postgresql/data
    x-omnistrate-compute:
      replicaCountAPIParam: numReadReplicas
      instanceTypes:
        - cloudProvider: aws
          apiParam: replicaInstanceType
        - cloudProvider: gcp
          apiParam: replicaInstanceType
    x-omnistrate-capabilities:
      enableMultiZone: true
      endpointPerReplica: true
      autoscaling:
        maxReplicas: 5
        minReplicas: 1
        idleMinutesBeforeScalingDown: 2
        idleThreshold: 20
        overUtilizedMinutesBeforeScalingUp: 3
        overUtilizedThreshold: 80
      serverlessConfiguration:
        targetPort: 5432
        enableAutoStop: true
        minimumNodesInPool: 5
    environment:
      - POSTGRESQL_PASSWORD=$parameterGroup.var.postgresqlPassword
      - POSTGRESQL_MASTER_HOST=$master.sys.network.externalClusterServerlessEndpoint.endpointName
      - POSTGRESQL_PGAUDIT_LOG=READ,WRITE
      - POSTGRESQL_LOG_HOSTNAME=true
      - POSTGRESQL_REPLICATION_MODE=slave
      - POSTGRESQL_REPLICATION_USER=$parameterGroup.var.replUsername
      - POSTGRESQL_REPLICATION_PASSWORD=$parameterGroup.var.replPassword
      - POSTGRESQL_MASTER_PORT_NUMBER=$master.sys.network.externalClusterServerlessEndpoint.openPorts[0]
      - POSTGRESQL_DATA_DIR=/var/lib/postgresql/data/dbdata
      - SECURITY_CONTEXT_USER_ID=1001
      - SECURITY_CONTEXT_FS_GROUP=1001
      - SECURITY_CONTEXT_GROUP_ID=0
    x-omnistrate-api-params:
      - key: replicaInstanceType
        description: Replica Instance Type
        name: Replica Instance Type
        type: String
        modifiable: true
        required: true
        export: true
      - key: masterInstanceId
        description: Instance Id of the Master to connect
        name: Master Instance Id
        dependentResourceKey: Master
        type: Resource
        modifiable: true
        required: true
        export: true
      - key: parameterGroupId
        description: Replica configuration 
        name: Parameter Group Id
        dependentResourceKey: ParameterGroup
        type: Resource
        modifiable: true
        required: true
        export: true
      - key: numReadReplicas
        description: Number of Read Replicas
        name: Number of Read Replicas
        type: Float64
        modifiable: true
        required: false
        export: true
        defaultValue: "1"
        limits:
          min: 1
          max: 10

  ParameterGroup:
    image: omnistrate/noop
    x-omnistrate-api-params:
      - key: postgresqlUsername
        description: Default DB Username
        name: Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: postgresqlPassword
        description: Default DB Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
      - key: postgresqlDatabase
        description: Default DB Name
        name: Default Database
        type: String
        modifiable: false
        required: true
        export: true
      - key: postgresqlRootPassword
        description: Root Password
        name: Root DB Password
        type: String
        modifiable: false
        required: true
        export: false
      - key: replUsername
        description: Username
        name: Replication Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: replPassword
        description: Replication Password
        name: Replication Password
        type: String
        modifiable: false
        required: true
        export: false
```

## See it in action

Here is how it looks like:

[![Watch the video](https://img.youtube.com/vi/tQpc5V8_2vY/hqdefault.jpg)](https://youtu.be/tQpc5V8_2vY) 

Hopefully, this gave some idea on how one can take their data store technology and go from simply having a software to a fully-fledged working SaaS.

Of course, you can continue to evolve after building your first SaaS. For more on this, see [here](../../dev-ops-guides/upgrades.md#how-to-make-the-changes)
