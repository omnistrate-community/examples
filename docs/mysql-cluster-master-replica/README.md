---
tags:
  - example
  - database
  - mysql
  - cluster
  - master-replica
  - high-availability
---

<!-- TODO: MOVE TO GITHUB REPO -->
# MySQL Master-Replica Cluster resource example

In this example exercise, we will build a MySQL SaaS with a Master-Replica architecture leveraging a Cluster passive component.

## Complete example

Here is the complete example of the `compose.yaml` file:

```yaml
version: "3.9"

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
        - apiParam: instanceType
          cloudProvider: aws
        - apiParam: instanceType
          cloudProvider: gcp
        - apiParam: instanceType
          cloudProvider: azure 
    environment:
      - MYSQL_REPLICATION_MODE=master
      - MYSQL_REPLICATION_USER=repl_user
      - MYSQL_REPLICATION_PASSWORD=repl_password
      - MYSQL_PASSWORD=var.mysqlPassword
      - MYSQL_DATABASE=$var.mysqlDatabase
      - MYSQL_USER=$var.mysqlUsername
      - MYSQL_ROOT_PASSWORD=$var.mysqlRootPassword
      - SECURITY_CONTEXT_USER_ID=1001
      - SECURITY_CONTEXT_FS_GROUP=1001
      - SECURITY_CONTEXT_GROUP_ID=0
    x-omnistrate-api-params:
      - key: mysqlPassword
        description: MySQL Password
        name: Password
        type: String
        export: false
        required: true
        modifiable: false
      - key: mysqlUsername
        description: Default DB Username
        name: DB Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: mysqlDatabase
        description: Default DB Name
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
      - key: instanceType
        description: Instance Type for the Master
        name: Instance Type
        type: String
        modifiable: true
        required: true
        export: true
    x-omnistrate-mode-internal: true

  Replica:
    image: 'docker.io/bitnami/mysql:8.1.0'
    ports:
      - '3306'
    volumes:
      - ./data:/var/lib/mysql
    x-omnistrate-compute:
      instanceTypes:
        - apiParam: instanceType
          cloudProvider: aws
        - apiParam: instanceType
          cloudProvider: gcp
        - apiParam: instanceType
          cloudProvider: azure          
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
    environment:
      - MYSQL_MASTER_HOST=Master
      - MYSQL_REPLICATION_MODE=slave
      - MYSQL_REPLICATION_USER=repl_user
      - MYSQL_REPLICATION_PASSWORD=repl_password
      - MYSQL_USER=$var.mysqlUsername
      - MYSQL_PASSWORD=$var.mysqlPassword
      - MYSQL_DATABASE=$var.mysqlDatabase
      - MYSQL_MASTER_ROOT_PASSWORD=$var.mysqlRootPassword
      - MYSQL_MASTER_PORT_NUMBER=3306
      - SECURITY_CONTEXT_USER_ID=1001
      - SECURITY_CONTEXT_FS_GROUP=1001
      - SECURITY_CONTEXT_GROUP_ID=0
    x-omnistrate-api-params:
      - key: mysqlPassword
        description: MySQL Password
        name: Password
        type: String
        export: false
        required: true
        modifiable: false
      - key: mysqlUsername
        description: Default DB Username
        name: DB Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: mysqlDatabase
        description: Default DB Name
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
      - key: instanceType
        description: Instance Type for the Master
        name: Instance Type
        type: String
        modifiable: true
        required: true
        export: true
    x-omnistrate-mode-internal: true

  Cluster:
    image: omnistrate/noop
    x-omnistrate-api-params:
      - key: instanceType
        description: Instance Type
        name: Instance Type
        type: String
        modifiable: true
        required: true
        export: true
        parameterDependencyMap:
          Master: instanceType
          Replica: instanceType
      - key: mysqlPassword
        description: Password for MySQL
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
        parameterDependencyMap:
          Master: mysqlPassword
          Replica: mysqlPassword
      - key: mysqlUsername
        description: Username
        name: Default DB Username
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          Master: mysqlUsername
          Replica: mysqlUsername
      - key: mysqlDatabase
        description: Default database name
        name: Default Database
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          Master: mysqlDatabase
          Replica: mysqlDatabase
      - key: mysqlRootPassword
        description: Default root password
        name: Default root password
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          Master: mysqlRootPassword
          Replica: mysqlRootPassword
    depends_on:
      - Master
      - Replica
    x-omnistrate-mode-internal: false
```

Now we will break down the example. There are 3 components in the above compose spec. We will now go over each of those components in more detail below.

### Master service

This is the MySQL Master service. It is configured to run in Master mode and is responsible for handling all write operations.

Image selected is `docker.io/bitnami/mysql:8.1.0`, which is the official MySQL image from Bitnami.

Port `3306` (standard mysql) is exposed to the host machine and a volume is mounted to store the database data.

We have set `x-omnistrate-compute` to define the instance types for the service. This, paired with the `instanceType` API param will allow the user to select the instance type for the service, based on the cloud provider and the preferred type of instance (e.g. `t3.medium` for AWS, `e2-medium` for GCP or `Standard_B2s` for Azure).

We have set the necessary environment variables for the MySQL service to run in Master mode, included password, default database, username and root password, all of which are set as API params to allow your customer to set them.

We have set `x-omnistrate-mode-internal` to `true` to indicate that this service is an internal service and should not be exposed directly to your customers for configuration purposes.

```yaml
  Master:
    image: 'docker.io/bitnami/mysql:8.1.0'
    ports:
      - '3306'
    volumes:
      - ./data:/var/lib/mysql
    x-omnistrate-compute:
      instanceTypes:
        - apiParam: instanceType
          cloudProvider: aws
        - apiParam: instanceType
          cloudProvider: gcp
        - apiParam: instanceType
          cloudProvider: azure          
    environment:
      - MYSQL_REPLICATION_MODE=master
      - MYSQL_REPLICATION_USER=repl_user
      - MYSQL_REPLICATION_PASSWORD=repl_password
      - MYSQL_PASSWORD=var.mysqlPassword
      - MYSQL_DATABASE=$var.mysqlDatabase
      - MYSQL_USER=$var.mysqlUsername
      - MYSQL_ROOT_PASSWORD=$var.mysqlRootPassword
      - SECURITY_CONTEXT_USER_ID=1001
      - SECURITY_CONTEXT_FS_GROUP=1001
      - SECURITY_CONTEXT_GROUP_ID=0
    x-omnistrate-api-params:
      - key: mysqlPassword
        description: MySQL Password
        name: Password
        type: String
        export: false
        required: true
        modifiable: false
      - key: mysqlUsername
        description: Default DB Username
        name: DB Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: mysqlDatabase
        description: Default DB Name
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
      - key: instanceType
        description: Instance Type for the Master
        name: Instance Type
        type: String
        modifiable: true
        required: true
        export: true
    x-omnistrate-mode-internal: true
```

### Replica service

This is the MySQL Replica service. It is configured to run in Replica mode and responsible for handling read operations.
Image selected is the same as the Master service, same as the port, volume, compute instance and configuration visibility set up.
For the replica service we have set `x-omnistrate-capabilities` to define the capabilities of the service. In this case, we have enabled multi-zone deployment, set up an endpoint per replica, and configured autoscaling with a minimum of 1 replica, a maximum of 5 replicas, and set up the thresholds for scaling up and down.

```yaml
 Replica:
    image: 'docker.io/bitnami/mysql:8.1.0'
    ports:
      - '3306'
    volumes:
      - ./data:/var/lib/mysql
    x-omnistrate-compute:
      instanceTypes:
        - apiParam: instanceType
          cloudProvider: aws
        - apiParam: instanceType
          cloudProvider: gcp
        - apiParam: instanceType
          cloudProvider: azure          
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
    environment:
      - MYSQL_MASTER_HOST=Master
      - MYSQL_REPLICATION_MODE=slave
      - MYSQL_REPLICATION_USER=repl_user
      - MYSQL_REPLICATION_PASSWORD=repl_password
      - MYSQL_USER=$var.mysqlUsername
      - MYSQL_PASSWORD=$var.mysqlPassword
      - MYSQL_DATABASE=$var.mysqlDatabase
      - MYSQL_MASTER_ROOT_PASSWORD=$var.mysqlRootPassword
      - MYSQL_MASTER_PORT_NUMBER=3306
      - SECURITY_CONTEXT_USER_ID=1001
      - SECURITY_CONTEXT_FS_GROUP=1001
      - SECURITY_CONTEXT_GROUP_ID=0
    x-omnistrate-api-params:
      - key: mysqlPassword
        description: MySQL Password
        name: Password
        type: String
        export: false
        required: true
        modifiable: false
      - key: mysqlUsername
        description: Default DB Username
        name: DB Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: mysqlDatabase
        description: Default DB Name
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
      - key: instanceType
        description: Instance Type for the Master
        name: Instance Type
        type: String
        modifiable: true
        required: true
        export: true
    x-omnistrate-mode-internal: true
```

### Cluster service

This is the MySQL Cluster service. It is a passive component that does not run any service but is used to link the Master and Replica services and handle the configuration of your MySQL SaaS.

This is the only public service in the example, as it is the one that will be exposed to your customers for configuration purposes, it enables instance type, database, root password,initial user and password for your service. 

The deployment of the Cluster instance, orchestrating both Master and Replica will be automatically handled in the background by the Omnistrate platform so your customers do not link the services themselves.

```yaml
  Cluster:
    image: omnistrate/noop
    x-omnistrate-api-params:
      - key: instanceType
        description: Instance Type
        name: Instance Type
        type: String
        modifiable: true
        required: true
        export: true
        parameterDependencyMap:
          Master: instanceType
          Replica: instanceType
      - key: mysqlPassword
        description: Password for MySQL
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
        parameterDependencyMap:
          Master: mysqlPassword
          Replica: mysqlPassword
      - key: mysqlUsername
        description: Username
        name: Default DB Username
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          Master: mysqlUsername
          Replica: mysqlUsername
      - key: mysqlDatabase
        description: Default database name
        name: Default Database
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          Master: mysqlDatabase
          Replica: mysqlDatabase
      - key: mysqlRootPassword
        description: Default root password
        name: Default root password
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          Master: mysqlRootPassword
          Replica: mysqlRootPassword
    depends_on:
      - Master
      - Replica
    x-omnistrate-mode-internal: false
```
