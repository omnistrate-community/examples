---
tags:
  - example
  - database
  - mysql
  - serverless
  - master-replica
  - scaling
---

<!-- TODO: MOVE TO GITHUB REPO -->
# Serverless Master-Replica database example using MySQL

In this example exercise, we will build a MySQL SaaS with serverless capabilities enabled by Omnistrate and a master-replica architecture. 
Let's start with the simplest example and then the complete one, we will then break down the complete example to fully understand how it works.

## Hello world MySQL SaaS

Here is a hello world version of MySQL powered by bitnami images:

```yaml

version: "3"

services:
  Master:
    image: 'docker.io/bitnami/mysql:8.0.36'
    ports:
      - '3306'
    volumes:
      - ./data:/var/lib/mysql
    environment:
      - MYSQL_REPLICATION_MODE=master
      - MYSQL_REPLICATION_USER=repl_user
      - MYSQL_REPLICATION_PASSWORD=xFAwjmUcECktqL
      - MYSQL_PASSWORD=password
      - MYSQL_DATABASE=database
      - MYSQL_USER=username
      - MYSQL_ROOT_PASSWORD=root
      - SECURITY_CONTEXT_USER_ID=0
      - SECURITY_CONTEXT_FS_GROUP=0
      - SECURITY_CONTEXT_GROUP_ID=0

  Replica:
    image: 'docker.io/bitnami/mysql:8.0.36'
    ports:
      - '3306'
    volumes:
      - ./data:/var/lib/mysql
    environment:
      - MYSQL_MASTER_HOST=localhost
      - MYSQL_REPLICATION_MODE=slave
      - MYSQL_REPLICATION_USER=repl_user
      - MYSQL_REPLICATION_PASSWORD=xFAwjmUcECktqL
      - MYSQL_USER=username
      - MYSQL_DATABASE=database
      - MYSQL_MASTER_ROOT_PASSWORD=root
      - MYSQL_MASTER_PORT_NUMBER=3306
      - SECURITY_CONTEXT_USER_ID=0
      - SECURITY_CONTEXT_FS_GROUP=0
      - SECURITY_CONTEXT_GROUP_ID=0

```

This is the simplest version of a MySQL SaaS with a master-replica architecture. You can run this with `docker-compose up` and you will have a master and a replica running on your local machine.

In this case, the master-replica setup is achieved by leveraging the environment variables only on both the master and the replica side, setting up replication mode, user, password, and other MySQL environment variables.

```yaml
    environment:
      - MYSQL_MASTER_HOST=localhost
      - MYSQL_REPLICATION_MODE=slave
      - MYSQL_REPLICATION_USER=repl_user
      - MYSQL_REPLICATION_PASSWORD=xFAwjmUcECktqL
      - MYSQL_USER=username
      - MYSQL_DATABASE=database
      - MYSQL_MASTER_ROOT_PASSWORD=root
      - MYSQL_MASTER_PORT_NUMBER=3306
      - SECURITY_CONTEXT_USER_ID=0
      - SECURITY_CONTEXT_FS_GROUP=0
      - SECURITY_CONTEXT_GROUP_ID=0
```

On a sidenote, whenever you define your services and such services have a `password` or sensitive fields in their environment variables, you should random generated them and use a secret manager to store these values. You can then inject them into your services.
`MYSQL_REPLICATION_PASSWORD=xFAwjmUcECktqL` is an example of a sensitive field that should be stored in a secret manager.

## Serverless MySQL SaaS on Omnistrate

Now let's add some Omnistrate features to the recipe on top of making your MySQL serverless.

```yaml
version: "3"

x-customer-integrations:
  logs: 
  metrics: 

services:
  Master:
    image: 'docker.io/bitnami/mysql:8.1.0'
    ports:
      - '3306'
    volumes:
      - ./data:/var/lib/mysql
    x-omnistrate-compute:
      instanceTypes:
        - cloudProvider: aws
          apiParam: masterInstanceType
        - cloudProvider: gcp
          apiParam: masterInstanceType
        - cloudProvider: azure 
          apiParam: masterInstanceType        
    x-omnistrate-capabilities:
      serverlessConfiguration:
        targetPort: 3306
        enableAutoStop: true
        minimumNodesInPool: 1
    environment:
      - MYSQL_REPLICATION_MODE=master
      - MYSQL_REPLICATION_USER=repl_user
      - MYSQL_REPLICATION_PASSWORD=xFAwjmUcECktqL
      - MYSQL_PASSWORD=$parameterGroup.var.mysqlPassword
      - MYSQL_DATABASE=$parameterGroup.var.mysqlDatabase
      - MYSQL_USER=$parameterGroup.var.mysqlUsername
      - MYSQL_ROOT_PASSWORD=$parameterGroup.var.mysqlRootPassword
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
        description: Master configuration 
        name: Parameter Group Id
        dependentResourceKey: ParameterGroup
        type: Resource
        modifiable: true
        required: true
        export: true

  Replica:
    image: 'docker.io/bitnami/mysql:8.1.0'
    ports:
      - '3306'
    volumes:
      - ./data:/var/lib/mysql
    x-omnistrate-compute:
      replicaCountAPIParam: numReadReplicas
      instanceTypes:
        - cloudProvider: aws
          apiParam: replicaInstanceType
        - cloudProvider: gcp
          apiParam: replicaInstanceType
        - cloudProvider: azure
          apiParam: replicaInstanceType
    x-omnistrate-capabilities:
      enableMultiZone: true
      endpointPerReplica: true
      autoscaling:
        minReplicas: 1
        maxReplicas: 5
        idleMinutesBeforeScalingDown: 2
        idleThreshold: 20
        overUtilizedMinutesBeforeScalingUp: 3
        overUtilizedThreshold: 80
      serverlessConfiguration:
        targetPort: 3306
        enableAutoStop: true
        minimumNodesInPool: 1
    environment:
      - MYSQL_MASTER_HOST=$master.sys.network.externalClusterServerlessEndpoint.endpointName
      - MYSQL_REPLICATION_MODE=slave
      - MYSQL_REPLICATION_USER=repl_user
      - MYSQL_REPLICATION_PASSWORD=xFAwjmUcECktqL
      - MYSQL_USER=$parameterGroup.var.mysqlUsername
      - MYSQL_PASSWORD=$parameterGroup.var.mysqlPassword
      - MYSQL_DATABASE=$parameterGroup.var.mysqlDatabase
      - MYSQL_MASTER_ROOT_PASSWORD=$parameterGroup.var.mysqlRootPassword
      - MYSQL_MASTER_PORT_NUMBER=$master.sys.network.externalClusterServerlessEndpoint.openPorts[0]
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
      - key: mysqlUsername
        description: Default MySQL Username
        name: Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: mysqlPassword
        description: Default MySQL Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
      - key: mysqlDatabase
        description: Default MySQL Name
        name: Default Database
        type: String
        modifiable: false
        required: true
        export: true
      - key: mysqlRootPassword
        description: Root Password
        name: Root DB Password
        type: String
        modifiable: false
        required: true
        export: false
```

This is the final result! 

It could be a lot to digest so let's break it down.

We've added the `x-customer-integrations` section to enable logging and metrics [for your customers](../../build-guides/integrations.md#customer-observability), as follows:

```yaml
x-customer-integrations:
  logs: 
  metrics: 
```

We've also added the `x-omnistrate-compute` section and a custom parameter `x-omnistrate-api-params` to configure the instance types for the master and replica(s).

Here how to enable the instanceType on master:

```yaml
    x-omnistrate-compute:
      instanceTypes:
        - cloudProvider: aws
          apiParam: masterInstanceType
        - cloudProvider: gcp
          apiParam: masterInstanceType
        - cloudProvider: azure
          apiParam: masterInstanceType 
```

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

Now a very interesting one.

```yaml
    x-omnistrate-capabilities:
      enableMultiZone: true
      endpointPerReplica: true
      autoscaling:
        minReplicas: 1
        maxReplicas: 5
        idleMinutesBeforeScalingDown: 2
        idleThreshold: 20
        overUtilizedMinutesBeforeScalingUp: 3
        overUtilizedThreshold: 80
      serverlessConfiguration:
        targetPort: 3306
        enableAutoStop: true
        minimumNodesInPool: 1
```

Thanks to this piece of `x-omnistrate-capabilities` configuration we've enabled multi-zone support, endpoint per replica, autoscaling with a 1 to 5 setup.

Serverless capabilities are also there, running on the MySQL service port, with autostop enabled and a warmpool that counts 1 node. You can (and should) adjust these parameters to better fit your needs.


On top of this, to harden your service and avoid confusion for your users we made the hierarchical structure of this Master-Replica setup, pretty obvious.

Omnistrate linking management is a powerful feature that allows you to create a strong link between resources, enforced on the access side UI as well. 
In this case, we've created a link between the `Master` and `Replica` services.

```yaml
      - key: masterInstanceId
        description: Instance Id of the Master to connect
        name: Master Instance Id
        dependentResourceKey: Master
        type: Resource
        modifiable: true
        required: true
        export: true
```

This `dependentResourceKey` parameter means that when someone is creating a `Replica` they need to provide the `Master` instance id related to it, otherwise, the `Replica` cannot be created and the control plane for your service will enforce this.

We have also created the same link with our parameter group component on both the `Master` and `Replica` services.

This is how we've done it for the `Master` component:

```yaml
      - key: parameterGroupId
        description: Master configuration 
        name: Parameter Group Id
        dependentResourceKey: ParameterGroup
        type: Resource
        modifiable: true
        required: true
        export: true
```

This ensures that both Master and Replica have their own assigned `ParameterGroup` or they cannot be created.
We defined the `ParameterGroup` as follows:

```yaml
  ParameterGroup:
    image: omnistrate/noop
    x-omnistrate-api-params:
      - key: mysqlUsername
        description: Default MySQL Username
        name: Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: mysqlPassword
        description: Default MySQL Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
      - key: mysqlDatabase
        description: Default MySQL Name
        name: Default Database
        type: String
        modifiable: false
        required: true
        export: true
      - key: mysqlRootPassword
        description: Root Password
        name: Root DB Password
        type: String
        modifiable: false
        required: true
        export: false
```

The parameter group is a passive component that is used to store the configuration of the MySQL service. It's a way to centralize the configuration of the MySQL service and make it reusable across different services.
It's useful to avoid duplication and to enforce a standard configuration at the same time.

To create such a component we've used the `omnistrate/noop` image, which is a passive kind of image that does nothing (**no-op**erations) but is useful to create such components that are not defining running services.

Note: you can call such components in your preferred way based on their usage, in this case, we've called it `ParameterGroup` but you can call it `MySpecialConfig` or `MyAwesomeConfig` or whatever you want.

At the end of the day we've added a lot more than just serverless capabilities. We've added the ability to configure the instance types, the number of replicas, the ability to configure the MySQL environment variables via our API params, autoscaling, logging and metrics (enabled by OpenTelemetry), plus multi-zone support and endpoint for our replica(s).

We took the compose spec and added our platform capabilities to create a complete MySQL SaaS.

Here is how it looks like:

[![Watch the video](https://img.youtube.com/vi/fYWr1otnLWY/hqdefault.jpg)](https://www.youtube.com/watch?v=fYWr1otnLWY)

Try it yourself using the latest yaml configuration provided.
