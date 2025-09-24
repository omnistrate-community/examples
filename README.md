# Omnistrate Community Examples

This repository contains comprehensive examples and documentation for building SaaS applications using the Omnistrate platform. It provides ready-to-use configurations, detailed guides, and best practices for deploying various types of services as Software-as-a-Service offerings.

## Repository Structure

### 📁 `compose/examples/`

Contains Docker Compose and YAML configuration files for various services that can be deployed on Omnistrate:

#### `services/` - Docker Compose Examples
Ready-to-use Docker Compose files for popular services:

- **Databases**: `cassandra.yaml`, `clickhouse.yaml`, `couchbase.yaml`, `mariadb.yaml`, `mongo.yaml`, `mysql.yaml`, `postgres.yaml`, `postgres_cluster.yaml`, `postgis.yaml`, `redis.yaml`
- **Search & Analytics**: `opensearch.yaml`, `manticore-search.yaml`, `trino.yaml`
- **Streaming & Messaging**: `redpanda.yaml`, `timeplus.yaml`
- **AI/ML & Data**: `ferretdb.yaml`, `falkordb.yaml`, `mageai.yaml`, `privategpt.yaml`
- **Monitoring & Observability**: `prometheus.yaml`, `signoz.yaml`
- **Collaboration**: `outline_wiki.yaml`

#### `yamls/` - Service Plan Specifications
Advanced YAML configurations organized by service type, including:

- **Database Services**: `cassandra/`, `clickhouse/`, `couchbase/`, `mariadb/`, `mysql/`, `opensearch/`, `postgis/`, `postgres/`, `redis/`
- **Specialized Services**: `battery/`, `cnpg/`, `dremio/`, `ferretdb/`, `harbor/`, `levo/`, `motorhead/`, `nginx/`, `pulsar/`, `signoz/`, `wordpress/`
- **Platform Features**: `licensing/` - Examples for implementing licensing and billing features

#### `features/` - Platform Feature Examples
- `licensing.yaml` - Configuration examples for licensing and monetization features

### 📁 `docs/`

Comprehensive [documentation and tutorials](docs/README.md) for building specific types of SaaS applications. Review use cases for Database Solutions, AI & Machine Learning, Analytics & Data Processing, Monitoring and Observability, Marketplace integration and many more.

## Getting Started

1. **Choose Your Use Case**: Browse the `docs/` directory to find examples that match your requirements
2. **Review Configuration**: Check the corresponding files in `compose/examples/` for technical specifications
3. **Follow Documentation**: Each example includes step-by-step setup instructions
4. **Customize**: Adapt the configurations to your specific needs
5. **Deploy**: Use the Omnistrate platform to deploy your SaaS application

## Contributing

This is a community-driven repository. Contributions are welcome! Please feel free to:

- Add new service examples
- Improve existing documentation
- Share best practices and use cases
- Report issues or suggest improvements

## Resources

- [Omnistrate Documentation](https://docs.omnistrate.com)
- [Omnistrate Platform](https://omnistrate.com)
- [Community Support](https://github.com/omnistrate-community/examples/issues)

## License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.
