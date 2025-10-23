# On-Premises Deployment Guide

This guide explains how to define and configure on-premises (onprem) deployments using the Omnistrate service specification format.

## Overview

On-premises deployment allows you to deploy services in customer-managed environments. The specification defines how services are packaged, deployed, and managed in these environments.

## On-Premises Configuration

The `onPremDeployment` section contains AWS-specific bootstrap configuration used to store generated installer and artifacts:

```yaml
deployment:
  onPremDeployment:
    AwsAccountId: '339713121445'  # AWS account ID where installer and artifacts are stored
    AwsBootstrapRoleAccountArn: 'arn:aws:iam::339713121445:role/omnistrate-bootstrap-role'  # IAM role for accessing stored artifacts
```

This configuration specifies the AWS account and IAM role used to store generated installer packages and deployment artifacts. When you build an on-premises deployment, Omnistrate generates installer files and stores them in the specified AWS account.

## Deployment Requirements

The deployment section specifies the minimum requirements for the target environment:

```yaml
deployment:
  requirements:
    k8sVersion: ">=1.30.0"  # Minimum Kubernetes version required
```

## Service Definition

Services are defined in the `services` array. Each service can have:

- **name**: Unique identifier for the service
- **internal**: Whether the service is internal-only
- **disable**: Conditional disable flag (supports templating)
- **dependsOn**: List of services this service depends on
- **apiParameters**: Configuration parameters exposed to users
- **actionHooks**: Lifecycle hooks for validation, installation, backup
- **helmChartConfiguration**: Helm chart deployment details

## Example: Licensing Installer Service

Here's a complete example showing how to define a complex onprem service:

```yaml
name: licensing-installer
deployment:
  onPremDeployment:
    AwsAccountId: '339713121445'
    AwsBootstrapRoleAccountArn: 'arn:aws:iam::339713121445:role/omnistrate-bootstrap-role'
  onPremInstallerTools:
    helperUserScript: |
      #!/bin/bash
      log_error() {
        echo "Error: $1" > /tmp/error.log
      }

services:
  - name: DockerIO
    internal: true
    disable: "false"
    containerImagesRegistryCopyConfiguration:
       pullSource:
         registryURL: "docker.io"
         repositoryName: "library"
       pushTarget:
         registryURL: "docker.io"
         repositoryName: "omnistrate"
       images:
         - imageName: "redis"
           imageTag: "latest"
         - imageName: "nginx"
           imageTag: "latest"
         - imageName: "postgres"
           imageTag: "latest"

  - name: Omnistrate Docker
    internal: true
    apiParameters:
      - name: skipCustomImageRegistry
        key: skipCustomImageRegistry
        description: Skip a custom image registry for DataRobot images
        type: Boolean
        required: false
        export: true
        defaultValue: 'true'
        modifiable: false
      - name: privateRegistryUrl
        key: privateRegistryUrl
        description: "private"
        type: String
        required: false
        export: true
        defaultValue: "docker.io"
        modifiable: true
      - name: privateRegistryRepoName
        key: privateRegistryRepoName
        description: "private"
        type: String
        required: false
        export: true
        defaultValue: "omnistrate"
        modifiable: true
    disable: "{{ $var.skipCustomImageRegistry }}"
    containerImagesRegistryCopyConfiguration:
      pullSource:
        registryURL: "ghcr.io"
        repositoryName: "omnistrate-community"
      pushTarget:
        registryURL: "{{ $var.privateRegistryUrl }}"
        repositoryName: "{{ $var.privateRegistryRepoName }}"

  - name: Licensing Installer
    dependsOn:
      - Omnistrate Docker
      - DockerIO
    apiParameters:
      - name: skipCustomImageRegistry
        key: skipCustomImageRegistry
        description: Use a custom image registry for DataRobot images
        type: Boolean
        required: false
        export: true
        defaultValue: 'false'
        modifiable: false
        parameterDependencyMap:
          Omnistrate Docker: skipCustomImageRegistry
      - name: privateRegistryUrl
        key: privateRegistryUrl
        description: "private"
        type: String
        required: false
        defaultValue: "docker.io"
        export: true
        modifiable: true
        parameterDependencyMap:
          Omnistrate Docker: privateRegistryUrl
      - name: privateRegistryRepoName
        key: privateRegistryRepoName
        description: "private"
        type: String
        required: false
        defaultValue: "omnistrate"
        export: true
        modifiable: true
        parameterDependencyMap:
          Omnistrate Docker: privateRegistryRepoName
    actionHooks:
      - scope: CLUSTER
        type: VALIDATE
        commandTemplate: "echo 'Validate hook'"
      - scope: CLUSTER
        type: PRE_INSTALL
        commandTemplate: "echo 'Pre-install hook'"
      - scope: CLUSTER
        type: POST_INSTALL
        commandTemplate: "echo 'Post-install hook'"
      - scope: CLUSTER
        type: BACKUP
        commandTemplate: "echo 'Backup hook'"
    helmChartConfiguration:
      chartName: licensing-example-java-chart
      chartVersion: 0.1.14
      chartRepoName: omnistrate-community
      chartRepoURL: oci://ghcr.io/omnistrate-community
      autoDiscoverImagesTag: "omnistrate.com/images"
      releaseName: "licensing-example"
      namespace: "licensing-example"
      chartValues:
        replicaCount: 1
        image:
          repository: ghcr.io/omnistrate-community/licensing-example-java
          pullPolicy: IfNotPresent
          tag: 0.1.91
        subscriptionSecret:
          enabled: true
        affinity:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
                - matchExpressions:
                    - key: omnistrate.com/managed-by
                      operator: In
                      values:
                        - omnistrate
          podAntiAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              - labelSelector:
                  matchExpressions:
                    - key: omnistrate.com/schedule-mode
                      operator: In
                      values:
                        - exclusive
                namespaceSelector: {}
                topologyKey: kubernetes.io/hostname
```

## Detailed Explanation of Key Sections

### Container Images Registry Configuration

This section handles copying container images between registries:

```yaml
containerImagesRegistryCopyConfiguration:
  pullSource:
    registryURL: "docker.io"        # Source registry
    repositoryName: "library"       # Source repository
  pushTarget:
    registryURL: "docker.io"        # Target registry
    repositoryName: "omnistrate"    # Target repository
  images:
    - imageName: "redis"
      imageTag: "latest"
```

**Use Case**: When deploying in air-gapped environments, you need to copy images from public registries to private registries accessible in the customer's environment.

### API Parameters

Parameters allow users to customize the deployment:

```yaml
apiParameters:
  - name: skipCustomImageRegistry
    key: skipCustomImageRegistry
    description: Skip a custom image registry for DataRobot images
    type: Boolean                   # Data type: Boolean, String, Integer, etc.
    required: false
    export: true                    # Export to other services
    defaultValue: 'true'
    modifiable: false               # Can user change after deployment?
    parameterDependencyMap:          # Link to parent service parameters
      Omnistrate Docker: skipCustomImageRegistry
```

### Action Hooks

Lifecycle hooks execute at different deployment stages:

```yaml
actionHooks:
  - scope: CLUSTER                  # Scope: CLUSTER or INSTANCE
    type: VALIDATE                  # Type: VALIDATE, PRE_INSTALL, POST_INSTALL, BACKUP
    commandTemplate: "echo 'Validate hook'"
```

**Hook Types**:
- **VALIDATE**: Pre-deployment validation
- **PRE_INSTALL**: Before service installation
- **POST_INSTALL**: After service installation
- **BACKUP**: Backup operations

### Helm Chart Configuration

Defines how the service is deployed using Helm:

```yaml
helmChartConfiguration:
  chartName: licensing-example-java-chart
  chartVersion: 0.1.14
  chartRepoName: omnistrate-community
  chartRepoURL: oci://ghcr.io/omnistrate-community
  autoDiscoverImagesTag: "omnistrate.com/images"  # Auto-discover images with this tag
  releaseName: "licensing-example"
  namespace: "licensing-example"
  chartValues:
    # Custom values
```

### Service Dependencies

Services can depend on other services:

```yaml
dependsOn:
  - Omnistrate Docker
  - DockerIO
```

This ensures dependent services are deployed in the correct order.

### Helper Scripts

The `onPremInstallerTools` section allows you to define custom scripts that run during installation:

```yaml
deployment:
  onPremInstallerTools:
    helperUserScript: |
      #!/bin/bash
      log_error() {
        echo "Error: $1" > /tmp/error.log
      }
```

## Common Patterns

### Air-Gapped Deployment

For environments without internet access, use container image registry copying:

```yaml
containerImagesRegistryCopyConfiguration:
  pullSource:
    registryURL: "docker.io"
  pushTarget:
    registryURL: "private-registry.internal"
```

### Conditional Services

Disable services based on parameters:

```yaml
disable: "{{ $var.skipCustomImageRegistry }}"
```

## Related Resources

- [Omnistrate Service Specification Schema](https://api.omnistrate.cloud/2022-09-01-00/schema/service-spec-schema.json)
- [System Parameters Schema](https://api.omnistrate.cloud/2022-09-01-00/schema/system-parameters-schema.json)
- Helm Documentation: https://helm.sh/docs/
- Kubernetes Documentation: https://kubernetes.io/docs/
