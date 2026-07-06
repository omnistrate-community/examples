# Redis Operator Service Spec

This example defines a Redis Cluster service that is deployed by Omnistrate through the Opstree Redis Operator. Instead of deploying Redis directly from a Helm chart, the service installs the Redis Operator chart and then manages a `RedisCluster` custom resource through lifecycle workflows. The operator reconciles that custom resource into Redis leader and follower pods, services, persistent volumes, and status fields.

## What This Spec Creates

The service provisions:

| Component | Purpose |
|-----------|---------|
| Omnistrate service plan | Defines the Redis Operator offering and its tenancy, deployment account, features, and customer-facing parameters. |
| Redis Operator Helm dependency | Installs the Opstree Redis Operator into the Omnistrate-managed Kubernetes environment. |
| `RedisCluster` custom resource | Describes the Redis cluster that the operator should create and maintain (applied via `systemWorkflows.create`). |
| `redis-auth` Kubernetes secret | Stores the Redis password supplied through an Omnistrate API parameter (applied via workflow task). |
| AWS Network Load Balancer service | Exposes Redis publicly on port `6379`. |
| Persistent volume claims | Stores Redis data and per-node configuration. |
| Lifecycle workflows | `create`, `modify`, and `delete` workflows that manage the full lifecycle of Kubernetes resources. |

## Complete Spec

The full Redis Operator service spec is available in [spec.yaml](spec.yaml). Replace the AWS account placeholders with your provider account details before deploying it.

## Top-Level Service Plan

```yaml
name: Redis Operator
```

Names the Omnistrate service plan.

```yaml
deployment:
  hostedDeployment:
    AwsAccountId: "<AWS_ACCOUNT_ID>"
    AWSBootstrapRoleAccountArn: "arn:aws:iam::<AWS_ACCOUNT_ID>:role/omnistrate-bootstrap-role"
```

Deploys the service in the provider's AWS account. The bootstrap role is the IAM role Omnistrate uses to provision and manage infrastructure in that AWS account.

```yaml
tenancyType: CUSTOM_TENANCY
```

Uses custom tenancy placement. In this spec, the Kubernetes node affinity rules explicitly constrain where Redis pods can run by matching Omnistrate-managed labels, region, instance type, and resource ID.

```yaml
features:
  INTERNAL:
    logs: {}
    metrics: {}
  CUSTOMER:
    logs: {}
    metrics: {}
```

Enables Omnistrate-managed logs and metrics for both internal operator/provider visibility and customer-facing visibility.

## Service Definition

```yaml
services:
  - name: Redis Cluster
```

Defines one customer-facing service named `Redis Cluster`.

### Compute

```yaml
compute:
  instanceTypes:
    - apiParam: instanceType
      cloudProvider: aws
```

Lets the customer choose the AWS instance type through the `instanceType` API parameter. Omnistrate uses that value when selecting or provisioning compute for this resource.

### Network

```yaml
network:
  ports:
    - 6379
```

Declares Redis port `6379` as the service port.

### Customer Parameters

The `apiParameters` section defines values customers can provide when creating a Redis instance.

| Key | Type | Default | Modifiable | Required | Used For |
|-----|------|---------|------------|----------|----------|
| `instanceType` | `String` | `t3.medium` | Yes | No | AWS compute instance type for Redis nodes. |
| `redisPassword` | `Password` | None | No | Yes | Redis authentication password, stored in a Kubernetes secret. |
| `clusterSize` | `Float64` | `3` | No | No | Number of Redis leader and follower nodes requested in the `RedisCluster` CR. Minimum is `3`. |
| `storageSize` | `String` | `10Gi` | Yes | No | Persistent volume size for each Redis data volume. |

`export: true` makes these values available for templating through `$var.<parameterName>`.

## Endpoint Configuration

```yaml
endpointConfiguration:
  primary:
    host: "$sys.network.externalClusterEndpoint"
    ports:
      - 6379
    primary: true
    networkingType: PUBLIC
```

Defines the public Redis endpoint that customers use to connect. Omnistrate provides `$sys.network.externalClusterEndpoint`, and the Kubernetes `LoadBalancer` service is annotated so external DNS can map that hostname to the AWS load balancer.

## Operator CRD Configuration

The `operatorCRDConfiguration` section tells Omnistrate which Helm chart dependencies to install for the operator. Lifecycle management of the custom resource itself is handled by `systemWorkflows`.

### Helm Chart Dependency

```yaml
operatorCRDConfiguration:
  helmChartDependencies:
    - chartName: redis-operator
      chartVersion: 0.24.0
      chartRepoName: ot-helm
      chartRepoURL: https://ot-container-kit.github.io/helm-charts
      chartValues:
        redisOperator:
          webhook: false
        certmanager:
          enabled: false
```

Installs the Opstree Redis Operator Helm chart before any lifecycle workflows execute. Disables the operator webhook and cert-manager dependency to keep installation simpler when admission webhooks are not required.

## System Workflows

The `systemWorkflows` section defines the complete lifecycle for the Redis Cluster using an Argo Workflow-style structure. Each workflow uses DAG tasks that apply, patch, or delete Kubernetes resources.

### Create Workflow

When a customer creates a new Redis Cluster instance, Omnistrate executes the `create` workflow:

1. **applyRedisSecret** — Creates the `redis-auth` Kubernetes Secret with the base64-encoded password.
2. **applyRedisCluster** — Applies the `RedisCluster` custom resource (depends on the secret being created first).

```yaml
systemWorkflows:
  create:
    outputParameters:
      status: "$tasks.applyRedisCluster.resource.status.state"
      reason: "$tasks.applyRedisCluster.resource.status.reason"
      readyLeaderReplicas: "$tasks.applyRedisCluster.resource.status.readyLeaderReplicas"
      readyFollowerReplicas: "$tasks.applyRedisCluster.resource.status.readyFollowerReplicas"
    workflow:
      entrypoint: create
      arguments:
        parameters:
          - name: namespace
            value: "{{ $sys.namespace }}"
          - name: instanceId
            value: "{{ $sys.instanceId }}"
          - name: clusterSize
            value: "{{ $var.clusterSize }}"
          - name: storageSize
            value: "{{ $var.storageSize }}"
          - name: redisPasswordEncoded
            value: "{{ $func.base64encode($var.redisPassword) }}"
          - name: externalClusterEndpoint
            value: "{{ $sys.network.externalClusterEndpoint }}"
          - name: publicSubnetIds
            value: "{{ $sys.deploymentCell.publicSubnetIDs[*].id }}"
          - name: region
            value: "{{ $sys.deploymentCell.region }}"
          - name: instanceType
            value: "{{ $sys.compute.node.instanceType }}"
          - name: resourceId
            value: "{{ $sys.deployment.resourceID }}"
```

#### Output Parameters

The `outputParameters` block extracts status fields from the applied `RedisCluster` resource and surfaces them to the customer:

| Output | Source |
|--------|--------|
| `status` | `$tasks.applyRedisCluster.resource.status.state` |
| `reason` | `$tasks.applyRedisCluster.resource.status.reason` |
| `readyLeaderReplicas` | `$tasks.applyRedisCluster.resource.status.readyLeaderReplicas` |
| `readyFollowerReplicas` | `$tasks.applyRedisCluster.resource.status.readyFollowerReplicas` |

#### Readiness Detection

Instead of the deprecated `readinessConditions`, readiness is now modeled through the workflow task's `successCondition`:

```yaml
resource:
  action: apply
  successCondition: status.state == "Ready"
  failureCondition: status.state == "Error"
```

Omnistrate marks the instance as ready when the Redis Operator reports `status.state == "Ready"` on the `RedisCluster` resource. If the state becomes `"Error"`, the workflow fails.

#### Redis Auth Secret Task

```yaml
- name: apply-redis-secret
  resource:
    action: apply
    manifest: |
      apiVersion: v1
      kind: Secret
      metadata:
        name: redis-auth
        namespace: "{{inputs.parameters.namespace}}"
      type: Opaque
      data:
        password: "{{inputs.parameters.redisPasswordEncoded}}"
```

Creates the `redis-auth` secret referenced by the `RedisCluster` spec. The password comes from the customer-provided `redisPassword` parameter, base64-encoded via `$func.base64encode()` in the workflow arguments.

#### RedisCluster Resource Task

The `apply-redis-cluster` template creates the full `RedisCluster` custom resource:

```yaml
apiVersion: redis.redis.opstreelabs.in/v1beta2
kind: RedisCluster
metadata:
  name: "{{inputs.parameters.instanceId}}"
  namespace: "{{inputs.parameters.namespace}}"
```

The resource name uses `instanceId` to keep Kubernetes resources unique per service instance.

**Cluster settings:**

```yaml
spec:
  clusterSize: {{inputs.parameters.clusterSize}}
  clusterVersion: v7
  persistenceEnabled: true
  podSecurityContext:
    runAsUser: 1000
    fsGroup: 1000
```

Sets the requested cluster size, Redis major version, persistent storage, and runs Redis pods as user `1000` so the Redis process can read and write persistent data without running as root.

**Container configuration:**

```yaml
kubernetesConfig:
  image: quay.io/opstree/redis:latest
  imagePullPolicy: IfNotPresent
  redisSecret:
    name: redis-auth
    key: password
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

Configures the Redis image, points the operator to the secret, and sets Kubernetes CPU and memory requests/limits.

**Load Balancer service:**

```yaml
service:
  serviceType: LoadBalancer
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "{{inputs.parameters.externalClusterEndpoint}}"
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-subnets: "{{inputs.parameters.publicSubnetIds}}"
```

Creates an internet-facing AWS Network Load Balancer:

| Annotation | Meaning |
|------------|---------|
| `external-dns.alpha.kubernetes.io/hostname` | Publishes the Omnistrate endpoint hostname through ExternalDNS. |
| `aws-load-balancer-type: external` | Uses the AWS Load Balancer Controller external load balancer path. |
| `aws-load-balancer-nlb-target-type: ip` | Targets pod IPs directly instead of node ports. |
| `aws-load-balancer-scheme: internet-facing` | Makes the load balancer publicly reachable. |
| `aws-load-balancer-subnets` | Places the load balancer in the Omnistrate deployment cell public subnets. |

**Pod scheduling (leader and follower):**

```yaml
redisLeader:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: omnistrate.com/managed-by
                operator: In
                values:
                  - omnistrate
              - key: topology.kubernetes.io/region
                operator: In
                values:
                  - "{{inputs.parameters.region}}"
              - key: node.kubernetes.io/instance-type
                operator: In
                values:
                  - "{{inputs.parameters.instanceType}}"
              - key: omnistrate.com/resource
                operator: In
                values:
                  - "{{inputs.parameters.resourceId}}"
```

Both `redisLeader` and `redisFollower` use identical affinity rules that force pods onto nodes that:

| Label | Purpose |
|-------|---------|
| `omnistrate.com/managed-by=omnistrate` | Ensures pods run on Omnistrate-managed nodes. |
| `topology.kubernetes.io/region` | Keeps pods in the current deployment cell region. |
| `node.kubernetes.io/instance-type` | Matches the selected customer instance type. |
| `omnistrate.com/resource` | Isolates scheduling to the node group associated with this Omnistrate resource. |

**Storage:**

```yaml
storage:
  volumeClaimTemplate:
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: "{{inputs.parameters.storageSize}}"
  nodeConfVolume: true
  nodeConfVolumeClaimTemplate:
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
```

Creates a persistent volume claim for Redis data using the customer-provided `storageSize`, plus an additional 1Gi volume for Redis node configuration to preserve cluster node identity across pod restarts.

### Modify Workflow

The `modify` workflow re-applies the `RedisCluster` resource with updated parameter values. It uses the same `apply-redis-cluster` template and `successCondition`/`failureCondition` as `create`, but skips the secret creation step (the secret is immutable).

```yaml
modify:
  outputParameters:
    status: "$tasks.applyRedisCluster.resource.status.state"
    ...
  workflow:
    entrypoint: modify
    ...
```

This runs when customers update modifiable parameters such as `instanceType` or `storageSize`.

### Delete Workflow

The `delete` workflow cleans up resources in order:

1. **deleteRedisCluster** — Deletes the `RedisCluster` custom resource. The operator garbage-collects pods, services, and PVCs.
2. **deleteRedisSecret** — Deletes the `redis-auth` secret (depends on the cluster being deleted first).

```yaml
delete:
  workflow:
    entrypoint: delete
    ...
    templates:
      - name: delete-redis-cluster
        resource:
          action: delete
          manifest: |
            apiVersion: redis.redis.opstreelabs.in/v1beta2
            kind: RedisCluster
            metadata:
              name: "{{inputs.parameters.instanceId}}"
              namespace: "{{inputs.parameters.namespace}}"
      - name: delete-redis-secret
        resource:
          action: delete
          manifest: |
            apiVersion: v1
            kind: Secret
            metadata:
              name: redis-auth
              namespace: "{{inputs.parameters.namespace}}"
```

## Runtime Variable Reference

The spec uses Omnistrate variables to connect customer inputs, generated infrastructure values, and Kubernetes manifests.

| Variable | Meaning |
|----------|---------|
| `$var.instanceType` | Customer-selected AWS instance type. |
| `$var.redisPassword` | Customer-provided Redis password. |
| `$var.clusterSize` | Customer-selected Redis cluster size. |
| `$var.storageSize` | Customer-selected Redis data volume size. |
| `$sys.namespace` | Kubernetes namespace for the instance. |
| `$sys.instanceId` | Unique Omnistrate instance identifier. |
| `$sys.network.externalClusterEndpoint` | Public DNS hostname assigned by Omnistrate. |
| `$sys.deploymentCell.region` | AWS region of the current deployment cell. |
| `$sys.deploymentCell.publicSubnetIDs[*].id` | Public subnet IDs used by the AWS load balancer. |
| `$sys.compute.node.instanceType` | Effective compute instance type chosen for the resource. |
| `$sys.deployment.resourceID` | Omnistrate resource ID used for node placement isolation. |
| `$func.base64encode(...)` | Omnistrate function used to encode the Redis password for a Kubernetes Secret. |
| `$tasks.<taskName>.resource.status.*` | Workflow output parameter expression that reads the applied resource's status fields. |

## Deployment Flow

1. A customer creates a Redis Cluster instance and provides required parameters such as `redisPassword`.
2. Omnistrate provisions compute based on `instanceType` and the service tenancy configuration.
3. Omnistrate installs the `redis-operator` Helm chart dependency from `operatorCRDConfiguration.helmChartDependencies`.
4. Omnistrate executes the `systemWorkflows.create` workflow:
   - The `applyRedisSecret` task creates the `redis-auth` Kubernetes Secret.
   - The `applyRedisCluster` task applies the `RedisCluster` custom resource.
5. The Redis Operator reconciles the custom resource into Redis leader and follower pods, services, and persistent volumes.
6. The Kubernetes `LoadBalancer` service creates an internet-facing AWS NLB.
7. ExternalDNS maps `$sys.network.externalClusterEndpoint` to the load balancer.
8. Omnistrate waits until the workflow `successCondition` (`status.state == "Ready"`) is met.
9. Omnistrate exposes the endpoint and output parameters to the user.

On deletion, Omnistrate executes `systemWorkflows.delete`, which removes the `RedisCluster` CR first (letting the operator garbage-collect pods and PVCs) and then deletes the auth secret.

## Operational Notes

- `redisPassword` is immutable after creation because changing Redis authentication on a live cluster requires a coordinated rollout.
- `clusterSize` is immutable in this spec. If cluster resizing is required, mark it modifiable only after validating the operator's scale-up and scale-down behavior.
- `storageSize` is modifiable, but actual volume expansion depends on the Kubernetes storage class and cloud provider support.
- The Redis image uses `latest`. For production, pin this to a tested Redis image tag to make upgrades explicit and repeatable.
- The load balancer is public and internet-facing. Restrict access with network policy, security groups, private networking, or application-level controls if the service should not be globally reachable.
- The Redis exporter is disabled. Enable it if you need Redis-specific Prometheus metrics in addition to Omnistrate's platform metrics.
- The deprecated `template`, `supplementalFiles`, `readinessConditions`, and top-level `outputParameters` fields are intentionally omitted; lifecycle resources and readiness checks are modeled with `systemWorkflows` following the [operator spec template](https://github.com/omnistrate-community/operator-spec-template).
