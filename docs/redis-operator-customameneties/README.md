# Redis Operator With Custom Amenities

This example uses the same Redis Cluster service spec as the [Redis Operator example](../redis-operator/README.md), but installs the Opstree Redis Operator as a deployment-cell custom amenity instead of declaring it under `operatorCRDConfiguration.helmChartDependencies` in the service spec.

Use this pattern when you need one Redis Operator installation per deployment cell, shared by all Redis service instances in that cell.

## Files

| File | Purpose |
|------|---------|
| [deployment-cell-config.yaml](deployment-cell-config.yaml) | Adds the `redis-operator` custom amenity that installs the `redis-operator` Helm chart. |
| [spec.yaml](spec.yaml) | Creates the Redis service and manages the `RedisCluster` custom resource through `systemWorkflows`. This spec intentionally does not include `helmChartDependencies`. |

## Deployment Cell Custom Amenity

The deployment cell config installs the Redis Operator Helm chart into the `redis-system` namespace:

```yaml
customAmenities:
  - name: redis-operator
    description: Redis in-memory data store
    type: Helm
    properties:
      ChartName: redis-operator
      ChartVersion: 0.24.0
      ChartRepoName: ot-helm
      ChartRepoURL: https://ot-container-kit.github.io/helm-charts
      ChartValues:
        redisOperator:
          webhook: false
        certmanager:
          enabled: false
      DefaultNamespace: redis-system
```

This approach is preferred when multiple service instances share the same cluster, because it avoids redundant operator installations and ensures consistent operator versioning across the cell.

## Service Spec Difference

The Redis service spec in [spec.yaml](spec.yaml) is structurally identical to the [redis-operator spec](../redis-operator/spec.yaml), with one key difference: it omits the `operatorCRDConfiguration.helmChartDependencies` block entirely.

In `../redis-operator/spec.yaml`:

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

In this spec, that block is removed because the `redis-operator` custom amenity handles the operator installation at the deployment-cell level.

## System Workflows

Both examples use the same `systemWorkflows` structure with `create`, `modify`, and `delete` lifecycle workflows. Each workflow uses DAG tasks that apply or delete Kubernetes resources through an Argo Workflow-style definition.

### Create Workflow

1. **applyRedisSecret** — Creates the `redis-auth` Kubernetes Secret with the base64-encoded password.
2. **applyRedisCluster** — Applies the `RedisCluster` custom resource (depends on the secret being created first).

Readiness is determined by the `successCondition` on the `apply-redis-cluster` task:

```yaml
resource:
  action: apply
  successCondition: status.state == "Ready"
  failureCondition: status.state == "Error"
```

Output parameters are extracted from the applied resource status:

```yaml
outputParameters:
  status: "$tasks.applyRedisCluster.resource.status.state"
  reason: "$tasks.applyRedisCluster.resource.status.reason"
  readyLeaderReplicas: "$tasks.applyRedisCluster.resource.status.readyLeaderReplicas"
  readyFollowerReplicas: "$tasks.applyRedisCluster.resource.status.readyFollowerReplicas"
```

### Modify Workflow

Re-applies the `RedisCluster` resource with updated parameter values (e.g., `instanceType`, `storageSize`). Skips secret creation since the password is immutable.

### Delete Workflow

Cleans up resources in order:

1. **deleteRedisCluster** — Deletes the `RedisCluster` CR. The operator garbage-collects pods, services, and PVCs.
2. **deleteRedisSecret** — Deletes the `redis-auth` secret after the cluster is removed.

## Deployment Flow

1. Update your deployment cell amenities with [deployment-cell-config.yaml](deployment-cell-config.yaml), following the [Deployment Cell Amenities guide](https://docs.omnistrate.com/operate-guides/deployment-cell-amenities/).
2. Build or update the Redis service using [spec.yaml](spec.yaml).
3. When a customer creates an instance, Omnistrate executes `systemWorkflows.create`:
   - The `applyRedisSecret` task creates the auth secret.
   - The `applyRedisCluster` task applies the `RedisCluster` custom resource.
4. The Redis Operator installed by the custom amenity reconciles the custom resource into Redis pods, services, and persistent volumes.
5. Omnistrate waits until `status.state == "Ready"` (the workflow `successCondition`).
6. The endpoint and output parameters are exposed to the customer.

On deletion, Omnistrate executes `systemWorkflows.delete`, removing the `RedisCluster` CR first and then the auth secret.

## When to Use This Pattern

| Scenario | Recommended Approach |
|----------|---------------------|
| One Redis service per deployment cell | Custom amenity (this example) |
| Multiple operator-backed services sharing an operator | Custom amenity (this example) |
| Self-contained service with its own operator lifecycle | `helmChartDependencies` in the spec ([redis-operator example](../redis-operator/README.md)) |
| Operator version pinned per service plan version | `helmChartDependencies` in the spec |

Use only one operator installation path for a given deployment cell: either the service-level `helmChartDependencies` pattern or this deployment-cell custom amenity pattern.
