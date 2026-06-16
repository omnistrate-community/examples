# Redis Operator Service Spec

This example defines a Redis Cluster service that is deployed by Omnistrate through the Opstree Redis Operator. Instead of deploying Redis directly from a Helm chart, the service installs the Redis Operator chart and then creates a `RedisCluster` custom resource. The operator reconciles that custom resource into Redis leader and follower pods, services, persistent volumes, and status fields.

## What This Spec Creates

The service provisions:

| Component | Purpose |
|-----------|---------|
| Omnistrate service plan | Defines the Redis Operator offering and its tenancy, deployment account, features, and customer-facing parameters. |
| Redis Operator Helm dependency | Installs the Opstree Redis Operator into the Omnistrate-managed Kubernetes environment. |
| `RedisCluster` custom resource | Describes the Redis cluster that the operator should create and maintain. |
| `redis-auth` Kubernetes secret | Stores the Redis password supplied through an Omnistrate API parameter. |
| AWS Network Load Balancer service | Exposes Redis publicly on port `6379`. |
| Persistent volume claims | Stores Redis data and per-node configuration. |
| Readiness and output parameters | Lets Omnistrate determine when the cluster is ready and show runtime status to users. |

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
    awsAccountId: "<AWS_ACCOUNT_ID>"
    awsBootstrapRoleAccountArn: "arn:aws:iam::<AWS_ACCOUNT_ID>:role/omnistrate-bootstrap-role"
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

The `operatorCRDConfiguration` section is the core of this spec. It tells Omnistrate which custom resource to create, which supporting manifests to apply, how to detect readiness, and which Helm chart dependency must be installed first.

### RedisCluster Template

```yaml
apiVersion: redis.redis.opstreelabs.in/v1beta2
kind: RedisCluster
metadata:
  name: {{ $sys.id }}
```

Creates an Opstree `RedisCluster` custom resource. The name is the Omnistrate resource ID, which helps keep Kubernetes resources unique per service instance.

```yaml
spec:
  clusterSize: {{ $var.clusterSize }}
  clusterVersion: v7
  persistenceEnabled: true
```

Sets the requested cluster size, Redis major version, and persistent storage behavior.

```yaml
podSecurityContext:
  runAsUser: 1000
  fsGroup: 1000
```

Runs Redis pods as user `1000` and assigns mounted volumes to group `1000`, so the Redis process can read and write persistent data without running as root.

### Redis Container Configuration

```yaml
kubernetesConfig:
  image: quay.io/opstree/redis:latest
  imagePullPolicy: IfNotPresent
  redisSecret:
    name: redis-auth
    key: password
```

Configures the Redis image and points the operator to the Kubernetes secret containing the Redis password.

```yaml
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

Sets Kubernetes CPU and memory requests and limits for Redis pods.

### Load Balancer Service

```yaml
service:
  serviceType: LoadBalancer
  annotations:
    external-dns.alpha.kubernetes.io/hostname: {{ $sys.network.externalClusterEndpoint }}
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-subnets: "{{ $sys.deploymentCell.publicSubnetIDs[*].id }}"
```

Creates an internet-facing AWS Network Load Balancer. The annotations request:

| Annotation | Meaning |
|------------|---------|
| `external-dns.alpha.kubernetes.io/hostname` | Publishes the Omnistrate endpoint hostname through ExternalDNS. |
| `aws-load-balancer-type: external` | Uses the AWS Load Balancer Controller external load balancer path. |
| `aws-load-balancer-nlb-target-type: ip` | Targets pod IPs directly instead of node ports. |
| `aws-load-balancer-scheme: internet-facing` | Makes the load balancer publicly reachable. |
| `aws-load-balancer-subnets` | Places the load balancer in the Omnistrate deployment cell public subnets. |

### Pod Scheduling

The `redisLeader` and `redisFollower` sections define node affinity rules.

```yaml
nodeSelectorTerms:
  - matchExpressions:
    - key: omnistrate.com/managed-by
      operator: In
      values:
      - omnistrate
    - key: topology.kubernetes.io/region
      operator: In
      values:
      - {{ $sys.deploymentCell.region }}
    - key: node.kubernetes.io/instance-type
      operator: In
      values:
      - {{ $sys.compute.node.instanceType }}
    - key: omnistrate.com/resource
      operator: In
      values:
      - {{ $sys.deployment.resourceID }}
```

These rules force Redis leader and follower pods onto nodes that:

| Label | Purpose |
|-------|---------|
| `omnistrate.com/managed-by=omnistrate` | Ensures pods run on Omnistrate-managed nodes. |
| `topology.kubernetes.io/region` | Keeps pods in the current deployment cell region. |
| `node.kubernetes.io/instance-type` | Matches the selected customer instance type. |
| `omnistrate.com/resource` | Isolates scheduling to the node group associated with this Omnistrate resource. |

### Redis Exporter

```yaml
redisExporter:
  enabled: false
```

Disables the Redis exporter sidecar. The image and resources are still declared, so the exporter can be enabled later with a small spec change if Redis-specific Prometheus metrics are needed.

### Storage

```yaml
storage:
  volumeClaimTemplate:
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: {{ $var.storageSize }}
```

Creates a persistent volume claim for Redis data using the customer-provided `storageSize`.

```yaml
nodeConfVolume: true
nodeConfVolumeClaimTemplate:
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 1Gi
```

Creates an additional persistent volume for Redis node configuration. This is useful for preserving cluster node identity and configuration across pod restarts.

## Supplemental Kubernetes Resources

```yaml
supplementalFiles:
  - |
    apiVersion: v1
    kind: Secret
    metadata:
      name: redis-auth
      namespace: {{ $sys.id }}
    type: Opaque
    data:
      password: {{ $func.base64encode($var.redisPassword) }}
```

Creates the `redis-auth` secret referenced by the `RedisCluster` template. The password comes from the customer-provided `redisPassword` parameter and is base64 encoded for the Kubernetes Secret `data` field.

## Readiness Conditions

```yaml
readinessConditions:
  "$var._crd.status.state": "Ready"
```

Marks the Omnistrate service instance as ready only when the Redis Operator reports the custom resource status state as `Ready`.

## Output Parameters

```yaml
outputParameters:
  "Status": "$var._crd.status.state"
  "Reason": "$var._crd.status.reason"
  "Ready Leader Replicas": "$var._crd.status.readyLeaderReplicas"
  "Ready Follower Replicas": "$var._crd.status.readyFollowerReplicas"
```

Surfaces operator status fields in Omnistrate so users can see the Redis cluster state, failure reason, and ready leader/follower replica counts.

## Helm Chart Dependency

```yaml
helmChartDependencies:
  - chartName: redis-operator
    chartVersion: 0.24.0
    chartRepoName: ot-helm
    chartRepoURL: https://ot-container-kit.github.io/helm-charts
```

Installs the Opstree Redis Operator Helm chart before applying the `RedisCluster` custom resource.

```yaml
chartValues:
  redisOperator:
    webhook: false
  certmanager:
    enabled: false
```

Disables the operator webhook and cert-manager dependency. This keeps installation simpler when admission webhooks are not required for this deployment.

## Runtime Variable Reference

The spec uses Omnistrate variables to connect customer inputs, generated infrastructure values, and Kubernetes manifests.

| Variable | Meaning |
|----------|---------|
| `$var.instanceType` | Customer-selected AWS instance type. |
| `$var.redisPassword` | Customer-provided Redis password. |
| `$var.clusterSize` | Customer-selected Redis cluster size. |
| `$var.storageSize` | Customer-selected Redis data volume size. |
| `$var._crd.status.*` | Status fields returned by the Redis Operator custom resource. |
| `$sys.id` | Unique Omnistrate resource or namespace identifier. |
| `$sys.network.externalClusterEndpoint` | Public DNS hostname assigned by Omnistrate. |
| `$sys.deploymentCell.region` | AWS region of the current deployment cell. |
| `$sys.deploymentCell.publicSubnetIDs[*].id` | Public subnet IDs used by the AWS load balancer. |
| `$sys.compute.node.instanceType` | Effective compute instance type chosen for the resource. |
| `$sys.deployment.resourceID` | Omnistrate resource ID used for node placement isolation. |
| `$func.base64encode(...)` | Omnistrate function used to encode the Redis password for a Kubernetes Secret. |

## Deployment Flow

1. A customer creates a Redis Cluster instance and provides required parameters such as `redisPassword`.
2. Omnistrate provisions compute based on `instanceType` and the service tenancy configuration.
3. Omnistrate installs the `redis-operator` Helm chart dependency.
4. Omnistrate applies the supplemental `redis-auth` secret.
5. Omnistrate renders and applies the `RedisCluster` custom resource.
6. The Redis Operator creates Redis leader and follower pods, services, and persistent volumes.
7. The Kubernetes `LoadBalancer` service creates an internet-facing AWS NLB.
8. ExternalDNS maps `$sys.network.externalClusterEndpoint` to the load balancer.
9. Omnistrate waits until `$var._crd.status.state` equals `Ready`.
10. Omnistrate exposes the endpoint and output parameters to the user.

## Operational Notes

- `redisPassword` is immutable after creation because changing Redis authentication on a live cluster requires a coordinated rollout.
- `clusterSize` is immutable in this spec. If cluster resizing is required, mark it modifiable only after validating the operator's scale-up and scale-down behavior.
- `storageSize` is modifiable, but actual volume expansion depends on the Kubernetes storage class and cloud provider support.
- The Redis image uses `latest`. For production, pin this to a tested Redis image tag to make upgrades explicit and repeatable.
- The load balancer is public and internet-facing. Restrict access with network policy, security groups, private networking, or application-level controls if the service should not be globally reachable.
- The Redis exporter is disabled. Enable it if you need Redis-specific Prometheus metrics in addition to Omnistrate's platform metrics.
