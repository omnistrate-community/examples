---
tags:
  - example
  - observability
  - otel
  - sidecar
  - monitoring
---

<!-- TODO: MOVE TO GITHUB REPO -->
# Configuring your custom Telemetry (OTEL) Exporter

Omnistrate provides out-of-the-box managed OTEL integrations for various observability providers. However, if you do not find the provider of your liking in the list, or you want to have more control over the whole process [custom sidecars](../../runtime-guides/custom-sidecars.md) resource capability allows you to configure OTEL sidecar container based on your needs easily.

In the following example, we will show you how you can use the [opentelemetry-collector-contrib](https://hub.docker.com/r/otel/opentelemetry-collector-contrib/) container with your own configuration.

## Define OTEL yaml configuration

Following is an example content of `otel-config.yaml` file that exports logs to Elasticsearch:

```yaml
receivers:
  filelog:
    include:
      - /var/log/pods/*/service/*.log # Collect logs from service container

exporters:
  elasticsearch:
    endpoint: https://elastic.example.com:9200 # Elasticsearch endpoint
    auth:
      authenticator: basicauth

extensions:
  basicauth: # Elasticsearch
    client_auth:
      username: your_user 
      password: your_very_secret_password 

processors:
  attributes:
    actions:
      - key: instance 
        value: {{ $sys.id }} # Adding tag with instanceID 
        action: insert
  batch: # Batching
    send_batch_size: 100
    timeout: 10s

service:
  extensions: [basicauth]
  pipelines:
    logs:
      receivers: [filelog]
      processors: [batch, attributes]
      exporters: [elasticsearch]
```

For more information on how to configure individual OTEL components, refer to [opentelemetry-collector-contrib GitHub repository](https://github.com/open-telemetry/opentelemetry-collector-contrib/).

## Define OTEL sidecar component

Following is an example of a simplified compose spec (non-relevant parts are omitted) that defines the OTEL sidecar component:

```yaml
services:
  MyServiceComponent:
    
    # ...
    # All additional Resource configuration omitted
    # ...
    
    volumes:
      # Define the mount of the otel-config.yaml file
      - /local/path/to/the/otel-config.yaml:/mnt/otel-config.yaml 
    x-omnistrate-capabilities:
      sidecars:
        otel:
          imageNameWithTag: "otel/opentelemetry-collector-contrib:0.116.1"
          command:
            - "/otelcol-contrib"
            - "--config"
            - "/mnt/otel-config.yaml" # Run the OTEL collector with the provided configuration 
          resourceLimits:
            cpu: "250m"
            memory: "256Mi"
          securityContext:
            runAsUser: 10001 # This is OTEL collector specific user 
            runAsGroup: 0
            runAsNonRoot: true
```

### Create the service

Only CTL allows the creation of service with additional file content (UI doesn't support it yet). You can use the following command to create the service:

```shell
omnistrate-ctl build --file compose.yaml --release-as-preferred --product-name "Your product name" --description "Your service description" 
```

### Deploy

Each instance of the above service will create an additional "sidecar-otel" container for the "MyServiceComponent" resource that will run the OTEL collector with the supplied configuration.
