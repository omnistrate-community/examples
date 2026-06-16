# Redis Operator With Custom Amenities

This example uses the same Redis Cluster service spec as the [Redis Operator example](../redis-operator/README.md), but installs the Opstree Redis Operator as a deployment-cell custom amenity instead of declaring it under `helmChartDependencies` in the service spec.

Use this pattern when you need one Redis Operator installation per deployment cell, reused by Redis service instances in that cell.

## Files

| File | Purpose |
|------|---------|
| [deployment-cell-config.yaml](deployment-cell-config.yaml) | Adds the `redis-operator` custom amenity that installs the `redis-operator` Helm chart. |
| [spec.yaml](spec.yaml) | Creates the Redis service and `RedisCluster` custom resource. This spec intentionally does not include `helmChartDependencies`. |

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

## Service Spec Difference

The Redis service spec in [spec.yaml](spec.yaml) is the same Redis Cluster service definition, with one important difference: it removes this service-level dependency block:

```yaml
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

That block is not needed because the `redis-operator` custom amenity installs the operator for the deployment cell.

## Deployment Flow

1. Update your deployment cell amenities with [deployment-cell-config.yaml](deployment-cell-config.yaml), following the [Deployment Cell Amenities guide](https://docs.omnistrate.com/operate-guides/deployment-cell-amenities/).
2. Build or update the Redis service using [spec.yaml](spec.yaml).
3. Omnistrate creates the `RedisCluster` custom resource for each service instance.
4. The Redis Operator installed by the `redis-operator` custom amenity reconciles the custom resource into Redis pods, services, and persistent volumes.

Use only one operator installation path for a given deployment cell: either the service-level `helmChartDependencies` pattern in [../redis-operator/spec.yaml](../redis-operator/spec.yaml), or this deployment-cell custom amenity pattern.
