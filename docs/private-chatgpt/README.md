# Private ChatGPT

This example shows how to deploy a private ChatGPT instance.
[PrivateGPT](https://github.com/imartinez/privateGPT) is a private and lean version of OpenAI's chatGPT that can be used to create a private chatbot, capable of ingesting your documents and answering questions about them. 
You are basically having a conversation with your documents run by the open-source model of your choice that will be used to generate the answers.

Shoutout to [Ivan Martinez](https://github.com/imartinez) for creating and maintaining this amazing project.

## Getting started via compose spec

To get started via compose spec, provided below we have a sample that you can use to deploy a simple instance of privateGPT.

```yaml
version: '3.9'
services:
  private-gpt:
    x-omnistrate-compute:
      instanceTypes:
      - cloudProvider: aws
        apiParam: instanceType
      - cloudProvider: gcp
        apiParam: instanceType
      - cloudProvider: azure
        apiParam: instanceType        
    x-omnistrate-capabilities:
      httpReverseProxy:
        targetPort: 8080
      enableMultiZone: true
      enableEndpointPerReplica: false
    x-omnistrate-api-params:
    - key: instanceType
      description: Instance Type
      name: Instance Type
      type: String
      modifiable: true
      required: true
      export: true
      defaultValue: g5.xlarge
      options:
      - g5.xlarge
      - g5.2xlarge
      - g5.4xlarge
    - key: instanceStorageIOPS
      description: Instance Storage IOPS, in IOPS 
      name: Instance Storage IOPS (AWS Only)
      type: Float64
      modifiable: true
      required: true
      export: true
      defaultValue: "300"
    - key: instanceStorageThroughput
      description: Instance Storage Throughput, in MB/s
      name: Instance Storage Throughput (AWS Only)
      type: Float64
      modifiable: true
      required: true
      export: true
      defaultValue: "125"
    - key: instanceStorageSizeGi
      description: Instance Storage Size, at least large enough to hold the model file
      name: Instance Storage Size (GiB)
      type: Float64
      modifiable: true
      required: true
      export: true
      defaultValue: "10"
    - key: fileURL
      description: Model File URL
      name: Model File URL
      type: String
      modifiable: true
      required: true
      export: true
      defaultValue: "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.1-GGUF/resolve/main/mistral-7b-instruct-v0.1.Q4_K_M.gguf"
    image: ghcr.io/omnistrate/private-gpt:1.0
    volumes:
      - source: ./local_data/
        target: /home/worker/app/local_data
        type: bind
        x-omnistrate-storage:
          aws:
            instanceStorageType: AWS::EBS_GP3
            instanceStorageSizeGi: 100
          gcp:
            instanceStorageType: GCP::PD_SSD
            instanceStorageSizeGi: 100
          azure:
            instanceStorageType: AZURE::PREMIUM_SSD
            instanceStorageSizeGi: 100            
      - source: ./models/
        target: /home/worker/app/models
        type: bind
        x-omnistrate-storage:
          aws:
            instanceStorageType: AWS::EBS_GP3
            instanceStorageSizeGiAPIParam: instanceStorageSizeGi
            instanceStorageIOPSAPIParam: instanceStorageIOPS
            instanceStorageThroughputAPIParam: instanceStorageThroughput
          gcp:
            instanceStorageType: GCP::PD_SSD
            instanceStorageSizeGiAPIParam: instanceStorageSizeGi
          azure:
            instanceStorageType: AZURE::PREMIUM_SSD
            instanceStorageSizeGiAPIParam: instanceStorageSizeGi            
    ports:
      - 8001:8080
    environment:
      PORT: 8080
      PGPT_PROFILES: docker
      PGPT_MODE: local
      FILE_URL: $var.fileURL
```

Note that this image has been built from a fork of the original privateGPT repo, with some minor changes to make it work within Omnistrate like adding an entrypoint script to download the model by default. 
You can find the source code changes we made [here](https://github.com/imartinez/privateGPT/pull/1428).

You can use as example the following file URL: `https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.1-GGUF/resolve/main/mistral-7b-instruct-v0.1.Q4_K_M.gguf`

Voilà! You have deployed a privateGPT component.

# ![PrivateGPT-1](../../images/privateGPT-1.png)

## Deploying PrivateGPT in your customers cloud (BYOC)

Now, if you want to deploy privateGPT in your customers account, you can do so by enabling BYOA.

## How to enable BYOC

Once you have created your Omnistrate account and have access to your Service Dashboard you can connect your host cloud provider account and your customers account by following the [BYOC guide](../../usecases/byoc.md).

Once you have connected your customers account, you can deploy privateGPT in their account as well.

Alternatively, to set up your host account via template, you can just add it in the compose spec as follows:

```yaml
version: '3.9'
x-omnistrate-byoa:
  awsAccountId: 'your-aws-account-id'
  awsBootstrapRoleAccountArn: 'arn:aws:iam::your-aws-account-id:role/omnistrate-bootstrap-role'
services:
  private-gpt:
    x-omnistrate-compute:
      instanceTypes:
      - cloudProvider: aws
        apiParam: instanceType
      - cloudProvider: gcp
        apiParam: instanceType
      - cloudProvider: azure
        apiParam: instanceType        
    x-omnistrate-capabilities:
      httpReverseProxy:
        targetPort: 8080
      enableMultiZone: true
      enableEndpointPerReplica: false
    x-omnistrate-api-params:
    - key: instanceType
      description: Instance Type
      name: Instance Type
      type: String
      modifiable: true
      required: true
      export: true
      defaultValue: g5.xlarge
      options:
      - g5.xlarge
      - g5.2xlarge
      - g5.4xlarge
    - key: instanceStorageIOPS
      description: Instance Storage IOPS, in IOPS 
      name: Instance Storage IOPS (AWS Only)
      type: Float64
      modifiable: true
      required: true
      export: true
      defaultValue: "300"
    - key: instanceStorageThroughput
      description: Instance Storage Throughput, in MB/s
      name: Instance Storage Throughput (AWS Only)
      type: Float64
      modifiable: true
      required: true
      export: true
      defaultValue: "125"
    - key: instanceStorageSizeGi
      description: Instance Storage Size, at least large enough to hold the model file
      name: Instance Storage Size (GiB)
      type: Float64
      modifiable: true
      required: true
      export: true
      defaultValue: "10"
    - key: fileURL
      description: Model File URL
      name: Model File URL
      type: String
      modifiable: true
      required: true
      export: true
      defaultValue: "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.1-GGUF/resolve/main/mistral-7b-instruct-v0.1.Q4_K_M.gguf"
    image: ghcr.io/omnistrate/private-gpt:1.0
    volumes:
      - source: ./local_data/
        target: /home/worker/app/local_data
        type: bind
        x-omnistrate-storage:
          aws:
            instanceStorageType: AWS::EBS_GP3
            instanceStorageSizeGi: 100
          gcp:
            instanceStorageType: GCP::PD_SSD
            instanceStorageSizeGi: 100
          azure:
            instanceStorageType: AZURE::PREMIUM_SSD
            instanceStorageSizeGi: 100
      - source: ./models/
        target: /home/worker/app/models
        type: bind
        x-omnistrate-storage:
          aws:
            instanceStorageType: AWS::EBS_GP3
            instanceStorageSizeGiAPIParam: instanceStorageSizeGi
            instanceStorageIOPSAPIParam: instanceStorageIOPS
            instanceStorageThroughputAPIParam: instanceStorageThroughput
          gcp:
            instanceStorageType: GCP::PD_SSD
            instanceStorageSizeGiAPIParam: instanceStorageSizeGi
          azure:
            instanceStorageType: AZURE::PREMIUM_SSD
            instanceStorageSizeGiAPIParam: instanceStorageSizeGi
    ports:
      - 8001:8080
    environment:
      PORT: 8080
      PGPT_PROFILES: docker
      PGPT_MODE: local
      FILE_URL: $var.fileURL
```

Note that setting up your customers account still requires you to follow the steps in the [BYOA guide](../../usecases/byoc.md).

You can enable our observability features by adding the following to your compose spec:

```yaml
x-customer-integrations:
  logs: 
  metrics: 
```

The final compose spec will look like this:

```yaml
version: '3.9'
x-omnistrate-byoa:
  awsAccountId: 'your-aws-account-id'
  awsBootstrapRoleAccountArn: 'arn:aws:iam::your-aws-account-id:role/omnistrate-bootstrap-role'
x-customer-integrations:
  logs: 
  metrics: 
services:
  private-gpt:
    x-omnistrate-compute:
      instanceTypes:
      - cloudProvider: aws
        apiParam: instanceType
      - cloudProvider: gcp
        apiParam: instanceType
      - cloudProvider: azure
        apiParam: instanceType        
    x-omnistrate-capabilities:
      httpReverseProxy:
        targetPort: 8080
      enableMultiZone: true
      enableEndpointPerReplica: false
    x-omnistrate-api-params:
    - key: instanceType
      description: Instance Type
      name: Instance Type
      type: String
      modifiable: true
      required: true
      export: true
      defaultValue: g5.xlarge
      options:
      - g5.xlarge
      - g5.2xlarge
      - g5.4xlarge
    - key: instanceStorageIOPS
      description: Instance Storage IOPS, in IOPS 
      name: Instance Storage IOPS (AWS Only)
      type: Float64
      modifiable: true
      required: true
      export: true
      defaultValue: "300"
    - key: instanceStorageThroughput
      description: Instance Storage Throughput, in MB/s
      name: Instance Storage Throughput (AWS Only)
      type: Float64
      modifiable: true
      required: true
      export: true
      defaultValue: "125"
    - key: instanceStorageSizeGi
      description: Instance Storage Size, at least large enough to hold the model file
      name: Instance Storage Size (GiB)
      type: Float64
      modifiable: true
      required: true
      export: true
      defaultValue: "10"
    - key: fileURL
      description: Model File URL
      name: Model File URL
      type: String
      modifiable: true
      required: true
      export: true
      defaultValue: "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.1-GGUF/resolve/main/mistral-7b-instruct-v0.1.Q4_K_M.gguf"
    image: ghcr.io/omnistrate/private-gpt:1.0
    volumes:
      - source: ./local_data/
        target: /home/worker/app/local_data
        type: bind
        x-omnistrate-storage:
          aws:
            instanceStorageType: AWS::EBS_GP3
            instanceStorageSizeGi: 100
          gcp:
            instanceStorageType: GCP::PD_SSD
            instanceStorageSizeGi: 100
          azure:
            instanceStorageType: AZURE::PREMIUM_SSD
            instanceStorageSizeGi: 100            
      - source: ./models/
        target: /home/worker/app/models
        type: bind
        x-omnistrate-storage:
          aws:
            instanceStorageType: AWS::EBS_GP3
            instanceStorageSizeGiAPIParam: instanceStorageSizeGi
            instanceStorageIOPSAPIParam: instanceStorageIOPS
            instanceStorageThroughputAPIParam: instanceStorageThroughput
          gcp:
            instanceStorageType: GCP::PD_SSD
            instanceStorageSizeGiAPIParam: instanceStorageSizeGi
          azure:
            instanceStorageType: AZURE::PREMIUM_SSD
            instanceStorageSizeGiAPIParam: instanceStorageSizeGi            
    ports:
      - 8001:8080
    environment:
      PORT: 8080
      PGPT_PROFILES: docker
      PGPT_MODE: local
      FILE_URL: $var.fileURL
```

## How to access your deployed privateGPT instance

Once you have deployed your privateGPT instance, you can access it via the Omnistrate UI by clicking on the "Connectivity" tab and then clicking copy the URL in your browser.

# ![PrivateGPT-2](../../images/privateGPT-2.png)

Now you can start having a conversation with your documents and leverage the power of privateGPT!

# ![PrivateGPT-3](../../images/privateGPT-3.png)

Reference to privateGPT doc [https://docs.privategpt.dev/](https://docs.privategpt.dev/)
