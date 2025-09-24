---
tags:
  - example
  - database
  - postgresql
  - byoc
  - deployment-model
---

<!-- TODO: MOVE TO GITHUB REPO -->
# PostgreSQL as a Hosted Solution and Bring your Own Cloud

This examples show how to deploy a Postgres SaaS in your account (provider hosted) and your customers account (BYOC hosted).

## Postgres in your account (provider hosted)

To deploy in provider hosted model, you need to connect a supported cloud provider account first, below you can check how it looks like in the compose spec.

For more info about onboarding with Omnistrate, you can visit our [getting started guide](../../getting-started/build-from-compose.md).

```yaml
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

x-customer-integrations:
  logs: 
  metrics: 

services:
  PGAdmin:
    image: omnistrate/pgadmin4:7.5
    ports:
      - 80:80
    volumes:
      - ./data:/var/lib/pgadmin
    x-omnistrate-compute:
      instanceTypes:
        - name: instanceType
          cloudProvider: aws
        - name: instanceType
          cloudProvider: gcp
        - name: instanceType
          cloudProvider: azure          
    x-omnistrate-capabilities:
      autoscaling:
        minReplicas: 1
        maxReplicas: 10
      httpReverseProxy:
        targetPort: 80
      enableMultiZone: true
      enableEndpointPerReplica: true
    environment:
      - DB_ENDPOINT= Writer
      - SECURITY_CONTEXT_FS_GROUP=0
      - SECURITY_CONTEXT_USER_ID=0
      - SECURITY_CONTEXT_GROUP_ID=0
      - PGADMIN_DEFAULT_EMAIL=$var.email
      - PGADMIN_SERVER_JSON_FILE=/tmp/servers.json
      - PGADMIN_DEFAULT_PASSWORD=$var.password
      - DB_USERNAME=$var.dbUser
    x-omnistrate-api-params:
      - key: email
        description: PGAdmin Email Address
        name: Email
        type: String
        export: true
        required: true
        modifiable: false
      - key: password
        description: PGAdmin Password
        name: Password
        type: String
        export: false
        required: true
        modifiable: false
      - key: dbUser
        description: Default DB Username
        name: DB Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: instanceType
        description: Instance Type for the PGAdmin cluster
        name: Instance Type
        type: String
        modifiable: true
        required: true
        export: true
    x-omnistrate-mode-internal: true
  Writer:
    image: bitnami/postgresql:latest
    ports:
      - 5432:5432
    volumes:
      - ./data:/var/lib/postgresql/data
    x-omnistrate-compute:
      instanceTypes:
        - cloudProvider: aws
          apiParam: writerInstanceType
        - cloudProvider: gcp
          apiParam: writerInstanceType
        - cloudProvider: azure
          apiParam: writerInstanceType          
    x-omnistrate-capabilities:
      enableEndpointPerReplica: true
    environment:
      - POSTGRESQL_PASSWORD=$var.postgresqlPassword
      - POSTGRESQL_DATABASE=$var.postgresqlDatabase
      - POSTGRESQL_USERNAME=$var.postgresqlUsername
      - POSTGRESQL_POSTGRES_PASSWORD=$var.postgresqlRootPassword
      - POSTGRESQL_PGAUDIT_LOG=READ,WRITE
      - POSTGRESQL_LOG_HOSTNAME=true
      - POSTGRESQL_REPLICATION_MODE=master
      - POSTGRESQL_REPLICATION_USER=repl_user
      - POSTGRESQL_REPLICATION_PASSWORD=repl_password
      - POSTGRESQL_DATA_DIR=/var/lib/postgresql/data/dbdata
      - SECURITY_CONTEXT_USER_ID=1001
      - SECURITY_CONTEXT_FS_GROUP=1001
      - SECURITY_CONTEXT_GROUP_ID=0
    x-omnistrate-api-params:
      - key: writerInstanceType
        description: Writer Instance Type
        name: Writer Instance Type
        type: String
        modifiable: true
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
      - key: postgresqlUsername
        description: Username
        name: Default DB Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: postgresqlRootPassword
        description: Root Password
        name: Root DB Password
        type: String
        modifiable: false
        required: false
        export: false
        defaultValue: rootpassword12345
    x-omnistrate-mode-internal: true
  Reader:
    image: bitnami/postgresql:latest
    ports:
      - 5433:5432
    volumes:
      - ./data:/var/lib/postgresql/data
    x-omnistrate-compute:
      instanceTypes:
        - cloudProvider: aws
          apiParam: readerInstanceType
        - cloudProvider: gcp
          apiParam: readerInstanceType
        - cloudProvider: azure
          apiParam: readerInstanceType          
    x-omnistrate-capabilities:
      enableMultiZone: true
      enableEndpointPerReplica: true
    environment:
      - POSTGRESQL_PASSWORD=$var.postgresqlPassword
      - POSTGRESQL_MASTER_HOST=Writer
      - POSTGRESQL_PGAUDIT_LOG=READ,WRITE
      - POSTGRESQL_LOG_HOSTNAME=true
      - POSTGRESQL_REPLICATION_MODE=slave
      - POSTGRESQL_REPLICATION_USER=repl_user
      - POSTGRESQL_REPLICATION_PASSWORD=repl_password
      - POSTGRESQL_MASTER_PORT_NUMBER=5432
      - POSTGRESQL_DATA_DIR=/var/lib/postgresql/data/dbdata
      - SECURITY_CONTEXT_USER_ID=1001
      - SECURITY_CONTEXT_FS_GROUP=1001
      - SECURITY_CONTEXT_GROUP_ID=0
    x-omnistrate-api-params:
      - key: readerInstanceType
        description: Reader Instance Type
        name: Reader Instance Type
        type: String
        modifiable: true
        required: true
        export: true
      - key: postgresqlPassword
        description: Default DB Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
      - key: postgresqlUsername
        description: Username
        name: Default DB Username
        type: String
        modifiable: false
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
          Writer: writerInstanceType
          Reader: readerInstanceType
          PGAdmin: instanceType
      - key: postgresqlPassword
        description: Default DB Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
        parameterDependencyMap:
          Writer: postgresqlPassword
          Reader: postgresqlPassword
          PGAdmin: password
      - key: postgresqlUsername
        description: Username
        name: Default DB Username
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          Writer: postgresqlUsername
          Reader: postgresqlUsername
          PGAdmin: dbUser
      - key: pgadminEmailAddress
        description: PGAdmin Email Address
        name: PGAdmin Email Address
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          PGAdmin: email
      - key: dbName
        description: Default Database Name
        name: Default Database
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          Writer: postgresqlDatabase
    depends_on:
      - Writer
      - Reader
      - PGAdmin
    x-omnistrate-mode-internal: false
```

The `hostedDeployment` section is used to declare your account as provider as follows:

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

You can also set it via our GUI when defining your service, by selecting the Deployment Model "provider account" and choosing your preferred account.

## Postgres in your customers account (BYOC hosted)

Deploying your service in your customer account, can be achieved by enabling the BYOC mode.
In this case, your provider account will act as an intermediary account, used to connect to your customer account.

[![Watch the video](../../images/byoc-access.png)](https://www.youtube.com/watch?v=eLehADgm1FA)

```yaml
version: '3.9'

x-omnistrate-service-plan:
  name: 'PostgreSQL Service'
  tenancyType: 'OMNISTRATE_DEDICATED_TENANCY'
  deployment:
    byoaDeployment:
      awsAccountId: 'xxxxxxxxxxx'
      awsBootstrapRoleAccountArn: 'arn:aws:iam::xxxxxxxxxxx:role/omnistrate-bootstrap-role'

x-customer-integrations:
  logs: 
  metrics: 

services:
  PGAdmin:
    image: omnistrate/pgadmin4:7.5
    ports:
      - 80:80
    volumes:
      - ./data:/var/lib/pgadmin
    x-omnistrate-compute:
      instanceTypes:
        - name: instanceType
          cloudProvider: aws
        - name: instanceType
          cloudProvider: gcp
        - name: instanceType
          cloudProvider: azure          
    x-omnistrate-capabilities:
      autoscaling:
        minReplicas: 1
        maxReplicas: 10
      httpReverseProxy:
        targetPort: 80
      enableMultiZone: true
      enableEndpointPerReplica: true
    environment:
      - DB_ENDPOINT= Writer
      - SECURITY_CONTEXT_FS_GROUP=0
      - SECURITY_CONTEXT_USER_ID=0
      - SECURITY_CONTEXT_GROUP_ID=0
      - PGADMIN_DEFAULT_EMAIL=$var.email
      - PGADMIN_SERVER_JSON_FILE=/tmp/servers.json
      - PGADMIN_DEFAULT_PASSWORD=$var.password
      - DB_USERNAME=$var.dbUser
    x-omnistrate-api-params:
      - key: email
        description: PGAdmin Email Address
        name: Email
        type: String
        export: true
        required: true
        modifiable: false
      - key: password
        description: PGAdmin Password
        name: Password
        type: String
        export: false
        required: true
        modifiable: false
      - key: dbUser
        description: Default DB Username
        name: DB Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: instanceType
        description: Instance Type for the PGAdmin cluster
        name: Instance Type
        type: String
        modifiable: true
        required: true
        export: true
    x-omnistrate-mode-internal: true
  Writer:
    image: bitnami/postgresql:latest
    ports:
      - 5432:5432
    volumes:
      - ./data:/var/lib/postgresql/data
    x-omnistrate-compute:
      instanceTypes:
        - cloudProvider: aws
          apiParam: writerInstanceType
        - cloudProvider: gcp
          apiParam: writerInstanceType
        - cloudProvider: azure 
          apiParam: writerInstanceType         
    x-omnistrate-capabilities:
      enableEndpointPerReplica: true
    environment:
      - POSTGRESQL_PASSWORD=$var.postgresqlPassword
      - POSTGRESQL_DATABASE=$var.postgresqlDatabase
      - POSTGRESQL_USERNAME=$var.postgresqlUsername
      - POSTGRESQL_POSTGRES_PASSWORD=$var.postgresqlRootPassword
      - POSTGRESQL_PGAUDIT_LOG=READ,WRITE
      - POSTGRESQL_LOG_HOSTNAME=true
      - POSTGRESQL_REPLICATION_MODE=master
      - POSTGRESQL_REPLICATION_USER=repl_user
      - POSTGRESQL_REPLICATION_PASSWORD=repl_password
      - POSTGRESQL_DATA_DIR=/var/lib/postgresql/data/dbdata
      - SECURITY_CONTEXT_USER_ID=1001
      - SECURITY_CONTEXT_FS_GROUP=1001
      - SECURITY_CONTEXT_GROUP_ID=0
    x-omnistrate-api-params:
      - key: writerInstanceType
        description: Writer Instance Type
        name: Writer Instance Type
        type: String
        modifiable: true
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
      - key: postgresqlUsername
        description: Username
        name: Default DB Username
        type: String
        modifiable: false
        required: true
        export: true
      - key: postgresqlRootPassword
        description: Root Password
        name: Root DB Password
        type: String
        modifiable: false
        required: false
        export: false
        defaultValue: rootpassword12345
    x-omnistrate-mode-internal: true
  Reader:
    image: bitnami/postgresql:latest
    ports:
      - 5433:5432
    volumes:
      - ./data:/var/lib/postgresql/data
    x-omnistrate-compute:
      instanceTypes:
        - cloudProvider: aws
          apiParam: readerInstanceType
        - cloudProvider: gcp
          apiParam: readerInstanceType
        - cloudProvider: azure
          apiParam: readerInstanceType          
    x-omnistrate-capabilities:
      enableMultiZone: true
      enableEndpointPerReplica: true
    environment:
      - POSTGRESQL_PASSWORD=$var.postgresqlPassword
      - POSTGRESQL_MASTER_HOST=Writer
      - POSTGRESQL_PGAUDIT_LOG=READ,WRITE
      - POSTGRESQL_LOG_HOSTNAME=true
      - POSTGRESQL_REPLICATION_MODE=slave
      - POSTGRESQL_REPLICATION_USER=repl_user
      - POSTGRESQL_REPLICATION_PASSWORD=repl_password
      - POSTGRESQL_MASTER_PORT_NUMBER=5432
      - POSTGRESQL_DATA_DIR=/var/lib/postgresql/data/dbdata
      - SECURITY_CONTEXT_USER_ID=1001
      - SECURITY_CONTEXT_FS_GROUP=1001
      - SECURITY_CONTEXT_GROUP_ID=0
    x-omnistrate-api-params:
      - key: readerInstanceType
        description: Reader Instance Type
        name: Reader Instance Type
        type: String
        modifiable: true
        required: true
        export: true
      - key: postgresqlPassword
        description: Default DB Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
      - key: postgresqlUsername
        description: Username
        name: Default DB Username
        type: String
        modifiable: false
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
          Writer: writerInstanceType
          Reader: readerInstanceType
          PGAdmin: instanceType
      - key: postgresqlPassword
        description: Default DB Password
        name: Password
        type: String
        modifiable: false
        required: true
        export: false
        parameterDependencyMap:
          Writer: postgresqlPassword
          Reader: postgresqlPassword
          PGAdmin: password
      - key: postgresqlUsername
        description: Username
        name: Default DB Username
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          Writer: postgresqlUsername
          Reader: postgresqlUsername
          PGAdmin: dbUser
      - key: pgadminEmailAddress
        description: PGAdmin Email Address
        name: PGAdmin Email Address
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          PGAdmin: email
      - key: dbName
        description: Default Database Name
        name: Default Database
        type: String
        modifiable: false
        required: true
        export: true
        parameterDependencyMap:
          Writer: postgresqlDatabase
    depends_on:
      - Writer
      - Reader
      - PGAdmin
    x-omnistrate-mode-internal: false
```

The `byoaDeployment` section is used to configure BYOC mode for your SaaS Product.

```yaml
x-omnistrate-service-plan:
  deployment:
    byoaDeployment:
      awsAccountId: 'xxxxxxxxxxx'
      awsBootstrapRoleAccountArn: 'arn:aws:iam::xxxxxxxxxxx:role/omnistrate-bootstrap-role'
```

You can also enable it via our GUI when defining your service, by selecting the Deployment Model "Bring Your Own Account (in your customer's account)" and choosing your preferred intermediary account.

After creating your service, your customers will be able to set their own cloud account.

To connect their account via Terraform they will follow [this video](https://www.youtube.com/watch?v=l6lMEZdMMxs), it will pop-up to them after they access your service.

In case they are using AWS we also offer a one-click setup solution for them here's a video about [how it works](https://www.youtube.com/watch?v=c3HNnM8UJBE).

Each of your customers will now be able to deploy your software in their own account.

For more details please visit the [BYOC architecture overview](../../build-guides/deployment-models.md#bring-your-own-cloud-byoc)
