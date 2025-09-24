---
tags:
  - example
  - analytics
  - trino
  - sql
---

<!-- TODO: MOVE TO GITHUB REPO -->
# Trino BYOC example

This example shows how to deploy a Trino SaaS in your customers account using BYOC mode.

[![Watch the video](../../images/trino-demo-screenshot.png)](https://www.youtube.com/watch?v=MRSHxL11MCY)

## Trino Architecture

Trino is an open source distributed SQL query engine for big data analytics, for running interactive analytic queries against data sources of all sizes ranging from gigabytes to petabytes.
Here's a diagram of the Trino architecture we will be deploying:

![Trino Architecture](../../images/trino-architecture.png)

## Getting started via compose spec

To get started via compose spec, provided below we have a sample that you can use to deploy a simple instance of Trino, note, this is not BYOC mode yet, scroll down for that. 

As for the images you can choose your preferred version of Postgres, Trino, Hive images. We are leveraging our custom ones that you can find in our [Docker Hub](https://hub.docker.com/u/omnistrate) but you can also use different ones as long as they are compatible.

```yaml
# logo: https://trino.io/assets/images/trino-logo/trino-ko_tiny-alt.svg
# description: Trino is a distributed SQL query engine for big data analytics.

version: '3.9'
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
volumes:
    hivedb: {}
    coordinatordb: {}
    workerdb: {}
    supersetdb: {}
services:
    postgres:
      x-omnistrate-capabilities:
        networkType: INTERNAL
      image: postgres:9
      x-omnistrate-api-params:
        - key: postgresqlPassword
          description: Default DB Password
          name: Password
          type: String
          modifiable: false
          required: true
          export: false
          defaultValue: ""
      environment:
      - SECURITY_CONTEXT_USER_ID=999
      - SECURITY_CONTEXT_GROUP_ID=999
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=$var.postgresqlPassword
      - PGDATA=/var/lib/postgresql/data/dbdata
      volumes:
        - hivedb:/var/lib/postgresql/data
      x-omnistrate-actionhooks:
      - scope: CLUSTER
        type: INIT
        commandTemplate: |
          PGPASSWORD={{ $var.postgresqlPassword }} psql -h postgres -U postgres -d postgres -c "CREATE DATABASE hive;"
          PGPASSWORD={{ $var.postgresqlPassword }} psql -h postgres -U postgres -d postgres -c "CREATE DATABASE superset;"
      ports:
        - "5432:5432"
      networks:
        ntrino:
          aliases:
            - postgres
      healthcheck:
          test: ["CMD-SHELL", "pg_isready -U postgres"]
          interval: "20s"
          timeout: "20s"
          retries: 3
      x-omnistrate-mode-internal: true

    hive:
      image: omnistrate/trino-hive:11.0
      container_name: hive
      x-omnistrate-api-params: 
      - key: postgresqlPassword
        description: Default DB Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
      - key: bucketAccessRoleARN
        description: Bucket Access Role ARN
        name: Bucket Access Role ARN
        type: String
        modifiable: true
        required: true
        export: true
      environment:
        - POSTGRES_PASSWORD=$var.postgresqlPassword
        - BUCKET_ACCESS_ROLE_ARN=$var.bucketAccessRoleARN
      volumes:
        - ./hive/scratch:/tmp/hive
        - ./hive/warehouse:/user/hive
        - ./hive/output:/opt/data/output
      ports:
        - "10000:10000"
        - "9083:9083"
      networks:
        ntrino:
          aliases:
            - hive
      x-omnistrate-mode-internal: true

    coordinator:
      x-omnistrate-capabilities:
        httpReverseProxy:
          targetPort: 8080
        enableMultiZone: true
        enableEndpointPerReplica: false
      x-omnistrate-api-params:
      - key: bucketAccessRoleARN
        description: Bucket Access Role ARN
        name: Bucket Access Role ARN
        type: String
        modifiable: true
        required: true
        export: true
      image: omnistrate/trino-coordinator:11.15
      container_name: coordinator
      ports:
        - "8080:8080"
      expose:
        - "8080"
      environment:
        - BUCKET_ACCESS_ROLE_ARN=$var.bucketAccessRoleARN
      volumes:
        - coordinatordb:/data/trino
        - ./hive/output:/opt/data/output
      networks:
        ntrino:
          aliases:
            - coordinator
      healthcheck:
          test: ["CMD-SHELL", "curl -sS http://localhost:8080/|| exit 1"]
          interval: "20s"
          timeout: "20s"
          retries: 3
      x-omnistrate-mode-internal: true

    worker:
      x-omnistrate-capabilities:
        httpReverseProxy:
          targetPort: 8080
        enableMultiZone: true
        enableEndpointPerReplica: false
      x-omnistrate-api-params:
      - key: bucketAccessRoleARN
        description: Bucket Access Role ARN
        name: Bucket Access Role ARN
        type: String
        modifiable: true
        required: true
        export: true
      image: omnistrate/trino-worker:11.15
      ports:
        - "8080:8080"
      environment:
        - BUCKET_ACCESS_ROLE_ARN=$var.bucketAccessRoleARN
      volumes:
        - workerdb:/data/trino
        - ./hive/output:/opt/data/output
      networks:
        ntrino:
          aliases:
            - worker
      x-omnistrate-mode-internal: true

    superset:
      x-omnistrate-capabilities:
        httpReverseProxy:
          targetPort: 8088
        enableMultiZone: true
        enableEndpointPerReplica: false
      image: omnistrate/superset:latest
      container_name: superset
      environment:
        - DATA_DIR=/opt/superset/data
        - SUPERSET_SECRET_KEY=HAjeudha2uahde*@Hau&@1
        - SECURITY_CONTEXT_USER_ID=0
        - SECURITY_CONTEXT_GROUP_ID=0
        - SECURITY_CONTEXT_FS_GROUP=0
      volumes:
      - supersetdb:/opt/superset/data
      ports:
        - "8088:8088"
      networks:
        ntrino:
          aliases:
            - superset
      x-omnistrate-mode-internal: true

    # trino-proxy:
    #   image: omnistrate/trino-proxy:latest
    #   container_name: "trino-proxy"
    #   networks:
    #     ntrino:
    #       aliases:
    #         - trino-proxy
    #   expose:
    #     - "8453"
    #     - "8001"
    #   ports:
    #     - "8453:8453"
    #     - "8001:8001"
    #   x-omnistrate-mode-internal: true

    Cluster:
      image: omnistrate/noop
      x-omnistrate-api-params:
      - key: postgresqlPassword
        description: Default DB Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
        parameterDependencyMap:
          postgres: postgresqlPassword
          hive: postgresqlPassword
      - key: bucketAccessRoleARN
        description: Bucket Access Role ARN
        name: Bucket Access Role ARN
        type: String
        modifiable: true
        required: true
        export: true
        parameterDependencyMap:
          hive: bucketAccessRoleARN
          coordinator: bucketAccessRoleARN
          worker: bucketAccessRoleARN
      depends_on:
        - postgres
        - hive
        - coordinator
        - worker
        - superset
        # - trino-proxy
      x-omnistrate-mode-internal: false

networks:
  ntrino: {}
```

### Deploy in BYOC mode

To deploy in BYOC mode, you need to set a customer account as follows:

```yaml
x-omnistrate-service-plan:
  name: 'PostgreSQL Service'
  tenancyType: 'OMNISTRATE_DEDICATED_TENANCY'
  deployment:
    byoaDeployment:
      awsAccountId: 'xxxxxxxxxxx'
      awsBootstrapRoleAccountArn: 'arn:aws:iam::xxxxxxxxxxx:role/omnistrate-bootstrap-role'
```

This goes instead of setting the `hostedDeployment` param, so the final yaml looks like this:

```yaml
version: '3.9'
x-omnistrate-service-plan:
  name: 'PostgreSQL Service'
  tenancyType: 'OMNISTRATE_DEDICATED_TENANCY'
  deployment:
    byoaDeployment:
      awsAccountId: 'xxxxxxxxxxx'
      awsBootstrapRoleAccountArn: 'arn:aws:iam::xxxxxxxxxxx:role/omnistrate-bootstrap-role'
volumes:
    hivedb: {}
    coordinatordb: {}
    workerdb: {}
    supersetdb: {}
services:
    postgres:
      x-omnistrate-capabilities:
        networkType: INTERNAL
      image: postgres:9
      x-omnistrate-api-params:
        - key: postgresqlPassword
          description: Default DB Password
          name: Password
          type: String
          modifiable: false
          required: true
          export: false
          defaultValue: ""
      environment:
      - SECURITY_CONTEXT_USER_ID=999
      - SECURITY_CONTEXT_GROUP_ID=999
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=$var.postgresqlPassword
      - PGDATA=/var/lib/postgresql/data/dbdata
      volumes:
        - hivedb:/var/lib/postgresql/data
      x-omnistrate-actionhooks:
      - scope: CLUSTER
        type: INIT
        commandTemplate: |
          PGPASSWORD={{ $var.postgresqlPassword }} psql -h postgres -U postgres -d postgres -c "CREATE DATABASE hive;"
          PGPASSWORD={{ $var.postgresqlPassword }} psql -h postgres -U postgres -d postgres -c "CREATE DATABASE superset;"
      ports:
        - "5432:5432"
      networks:
        ntrino:
          aliases:
            - postgres
      healthcheck:
          test: ["CMD-SHELL", "pg_isready -U postgres"]
          interval: "20s"
          timeout: "20s"
          retries: 3
      x-omnistrate-mode-internal: true

    hive:
      image: omnistrate/trino-hive:11.0
      container_name: hive
      x-omnistrate-api-params: 
      - key: postgresqlPassword
        description: Default DB Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
      - key: bucketAccessRoleARN
        description: Bucket Access Role ARN
        name: Bucket Access Role ARN
        type: String
        modifiable: true
        required: true
        export: true
      environment:
        - POSTGRES_PASSWORD=$var.postgresqlPassword
        - BUCKET_ACCESS_ROLE_ARN=$var.bucketAccessRoleARN
      volumes:
        - ./hive/scratch:/tmp/hive
        - ./hive/warehouse:/user/hive
        - ./hive/output:/opt/data/output
      ports:
        - "10000:10000"
        - "9083:9083"
      networks:
        ntrino:
          aliases:
            - hive
      x-omnistrate-mode-internal: true

    coordinator:
      x-omnistrate-capabilities:
        httpReverseProxy:
          targetPort: 8080
        enableMultiZone: true
        enableEndpointPerReplica: false
      x-omnistrate-api-params:
      - key: bucketAccessRoleARN
        description: Bucket Access Role ARN
        name: Bucket Access Role ARN
        type: String
        modifiable: true
        required: true
        export: true
      image: omnistrate/trino-coordinator:11.15
      container_name: coordinator
      ports:
        - "8080:8080"
      expose:
        - "8080"
      environment:
        - BUCKET_ACCESS_ROLE_ARN=$var.bucketAccessRoleARN
      volumes:
        - coordinatordb:/data/trino
        - ./hive/output:/opt/data/output
      networks:
        ntrino:
          aliases:
            - coordinator
      healthcheck:
          test: ["CMD-SHELL", "curl -sS http://localhost:8080/|| exit 1"]
          interval: "20s"
          timeout: "20s"
          retries: 3
      x-omnistrate-mode-internal: true

    worker:
      x-omnistrate-capabilities:
        httpReverseProxy:
          targetPort: 8080
        enableMultiZone: true
        enableEndpointPerReplica: false
      x-omnistrate-api-params:
      - key: bucketAccessRoleARN
        description: Bucket Access Role ARN
        name: Bucket Access Role ARN
        type: String
        modifiable: true
        required: true
        export: true
      image: omnistrate/trino-worker:11.15
      ports:
        - "8080:8080"
      environment:
        - BUCKET_ACCESS_ROLE_ARN=$var.bucketAccessRoleARN
      volumes:
        - workerdb:/data/trino
        - ./hive/output:/opt/data/output
      networks:
        ntrino:
          aliases:
            - worker
      x-omnistrate-mode-internal: true

    superset:
      x-omnistrate-capabilities:
        httpReverseProxy:
          targetPort: 8088
        enableMultiZone: true
        enableEndpointPerReplica: false
      image: omnistrate/superset:latest
      container_name: superset
      environment:
        - DATA_DIR=/opt/superset/data
        - SUPERSET_SECRET_KEY=HAjeudha2uahde*@Hau&@1
        - SECURITY_CONTEXT_USER_ID=0
        - SECURITY_CONTEXT_GROUP_ID=0
        - SECURITY_CONTEXT_FS_GROUP=0
      volumes:
      - supersetdb:/opt/superset/data
      ports:
        - "8088:8088"
      networks:
        ntrino:
          aliases:
            - superset
      x-omnistrate-mode-internal: true

    # trino-proxy:
    #   image: omnistrate/trino-proxy:latest
    #   container_name: "trino-proxy"
    #   networks:
    #     ntrino:
    #       aliases:
    #         - trino-proxy
    #   expose:
    #     - "8453"
    #     - "8001"
    #   ports:
    #     - "8453:8453"
    #     - "8001:8001"
    #   x-omnistrate-mode-internal: true

    Cluster:
      image: omnistrate/noop
      x-omnistrate-api-params:
      - key: postgresqlPassword
        description: Default DB Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
        parameterDependencyMap:
          postgres: postgresqlPassword
          hive: postgresqlPassword
      - key: bucketAccessRoleARN
        description: Bucket Access Role ARN
        name: Bucket Access Role ARN
        type: String
        modifiable: true
        required: true
        export: true
        parameterDependencyMap:
          hive: bucketAccessRoleARN
          coordinator: bucketAccessRoleARN
          worker: bucketAccessRoleARN
      depends_on:
        - postgres
        - hive
        - coordinator
        - worker
        - superset
        # - trino-proxy
      x-omnistrate-mode-internal: false

networks:
  ntrino: {}
```

You can set your customer(s) account(s) by following the [BYOC guide](../../usecases/byoc.md).

That's it! Now you can deploy your Trino stack in BYOC mode and set it up for as many customers as you want.
