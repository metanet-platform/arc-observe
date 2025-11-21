<div align="center">

# ARC Observe

**A Modified Version of Bitcoin SV's ARC Transaction Processor**

[![Go](https://img.shields.io/badge/Go-1.23%2B-blue)](https://golang.org/)

</div>

## About This Project

**ARC Observe** is a modified version of the [Bitcoin SV ARC (Authoritative Response Component)](https://github.com/bitcoin-sv/arc) transaction processor. This fork has been customized for observing and tracking Bitcoin SV transactions with a simplified deployment using PM2 instead of Kubernetes.

### Credits

This project is based on the original **ARC** developed by the Bitcoin SV team:
- **Original Project**: [bitcoin-sv/arc](https://github.com/bitcoin-sv/arc)
- **License**: Open BSV License
- **Copyright**: Bitcoin Association for BSV

All credit for the core transaction processing logic, architecture, and original implementation goes to the Bitcoin SV development team.

### What's Different in ARC Observe

This modified version includes:
- **Simplified Deployment**: PM2-based process management instead of Kubernetes
- **Native Binary Execution**: Runs directly on Linux with systemd integration
- **Streamlined Configuration**: Optimized for single-server deployments
- **Build Scripts**: Automated setup scripts for Ubuntu/Debian systems
- **PostgreSQL Support**: Compatible with any PostgreSQL database provider

### Original ARC Description

ARC is a transaction processor for Bitcoin that keeps track of the life cycle of a transaction as it is processed by the Bitcoin network. Next to the mining status of a transaction, ARC also keeps track of the various states that a transaction can be in.

## ⚠️ Disclaimer

This software is provided **AS IS** as a favor to promote decentralization of the Bitcoin SV network. It is offered without any guarantees, warranties, or representations of any kind, either express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, or non-infringement.

**USE AT YOUR OWN RISK.** The maintainers and contributors of this project are not liable for any damages, losses, or issues that may arise from using this software. Users are solely responsible for:
- Ensuring the software meets their requirements
- Testing thoroughly before production deployment
- Maintaining and securing their own infrastructure
- Complying with applicable laws and regulations

By using this software, you acknowledge that you understand and accept these terms.

## Table of Contents
- [Authoritative Response Component (ARC)](#authoritative-response-component-arc)
  - [Table of Contents](#table-of-contents)
  - [Documentation](#documentation)
  - [Configuration](#configuration)
  - [How to run ARC](#how-to-run-arc)
    - [Docker](#docker)
  - [Microservices](#microservices)
    - [API](#api)
      - [Integration into an echo server](#integration-into-an-echo-server)
    - [Metamorph](#metamorph)
      - [Metamorph transaction statuses](#metamorph-transaction-statuses)
      - [Metamorph stores](#metamorph-stores)
      - [Connections to Bitcoin nodes](#connections-to-bitcoin-nodes)
      - [Whitelisting](#whitelisting)
      - [ZMQ](#zmq)
    - [BlockTx](#blocktx)
      - [BlockTx stores](#blocktx-stores)
    - [Callbacker](#callbacker)
      - [Callbacker stores](#callbacker-stores)
  - [K8s-Watcher](#k8s-watcher)
  - [Message Queue](#message-queue)
  - [Broadcaster-cli](#broadcaster-cli)
  - [Tests](#tests)
    - [Unit tests](#unit-tests)
    - [Integration tests](#integration-tests)
    - [E2E tests](#e2e-tests)
  - [Monitoring](#monitoring)
    - [Prometheus](#prometheus)
    - [Profiler](#profiler)
    - [Tracing](#tracing)
  - [Building ARC](#building-arc)
    - [Generate grpc code](#generate-grpc-code)
    - [Generate REST API](#generate-rest-api)
    - [Generate REST API documentation](#generate-rest-api-documentation)
  - [Acknowledgements](#acknowledgements)
  - [Contribution Guidelines](#contribution-guidelines)
  - [Support \& Contacts](#support--contacts)

## Documentation

- Find full documentation at [https://bitcoin-sv.github.io/arc](https://bitcoin-sv.github.io/arc)

## Configuration

Settings for ARC Observe are defined in configuration files:

- **config_production.yaml**: Production deployment with remote database
- **config_local.yaml**: Local development configuration

The default configuration structure is shown in [config/example_config.yaml](./config/example_config.yaml). Each setting is documented in the file itself.

You can specify a custom config location using the `-config=<path>` flag when starting ARC.

ARC has default configuration values specified in code ([config/defaults.go](./config/defaults.go)), so you only need to specify settings you want to override. Example:
```yaml
---
logLevel: INFO
logFormat: text
network: mainnet
tracing:
  dialAddr: http://tracing:1234
```
The rest of the settings will be taken from defaults.

Each setting in the file `config.yaml` can be overridden with an environment variable. The environment variable needs to have this prefix `ARC_`. A sub setting will be separated using an underscore character. For example the following config setting could be overridden by the environment variable `ARC_METAMORPH_LISTENADDR`
```yaml
metamorph:
  listenAddr:
```

## How to run ARC Observe

ARC Observe is designed for simplified deployment using PM2 process manager on a single server.

### Prerequisites

1. **PostgreSQL Database**: Required for storing transaction and block data
   - Configure connection details in `config_production.yaml`
   - Run migrations before starting services (see [Database Setup](#database-setup))

2. **NATS Server**: Message queue for inter-service communication
   - Install NATS v2.10.7 or later
   - Will be managed by PM2 alongside ARC services

3. **Build Tools**: Required for compiling the ARC binary
   - Go 1.23.1 or later
   - GCC/build-essential (for CGO support)
   - Make

### Quick Start with PM2

1. **Clone the repository**:
```bash
git clone https://github.com/metanet-platform/arc-observe.git
cd arc-observe
```

2. **Run the setup script** (Ubuntu/Debian):
```bash
chmod +x setup-pm2.sh
sudo ./setup-pm2.sh
```

This script will:
- Install Go 1.23.1
- Install Node.js and PM2
- Install NATS Server v2.10.7
- Build the ARC binary with CGO support
- Set up PM2 to start on boot

3. **Configure your database** in `config_production.yaml`:
```yaml
metamorph:
  db:
    postgres:
      host: your-db-host
      port: 5432
      name: your-db-name
      user: your-db-user
      password: your-db-password
```

4. **Run database migrations**:
```bash
migrate -database "postgres://user:password@host:port/dbname?sslmode=disable" \
  -path internal/metamorph/store/postgresql/migrations up
  
migrate -database "postgres://user:password@host:port/dbname?sslmode=disable" \
  -path internal/blocktx/store/postgresql/migrations up
  
migrate -database "postgres://user:password@host:port/dbname?sslmode=disable" \
  -path internal/callbacker/store/postgresql/migrations up
```

5. **Start all services**:
```bash
pm2 start ecosystem.config.js
pm2 save
```

6. **Check status**:
```bash
pm2 status
pm2 logs
```

### PM2 Service Architecture

ARC Observe runs 5 separate PM2 processes:

| Service | Port | Description |
|---------|------|-------------|
| `nats-server` | 4222, 8222 | Message queue for inter-service communication |
| `arc-api` | 9090 | REST API for transaction submission |
| `arc-metamorph` | 8001 | Transaction processing and p2p network communication |
| `arc-blocktx` | 8011 | Block processing and transaction mining status |
| `arc-callbacker` | 8021 | Callback notifications for transaction status updates |

### Configuration Files

- **config_production.yaml**: Production configuration with database and network settings
- **config_local.yaml**: Local development configuration
- **ecosystem.config.js**: PM2 process configuration with memory limits and auto-restart
- **build.sh**: Script to rebuild the ARC binary after updates

### Storage & Broadcasting Optimization

ARC Observe includes two configurable parameters to optimize database storage and control network broadcasting:

#### 1. `storeAllBlockTransactions` (blocktx config)

Controls whether to store ALL transactions from blocks or only user-submitted ones:

- **`false` (recommended)**: Only stores user-submitted transactions (~95% storage reduction)
- **`true`**: Stores ALL transactions from every block (massive storage requirements)

```yaml
blocktx:
  storeAllBlockTransactions: false  # Recommended for most deployments
```

**Why disable it?**
- Arc-observe's primary purpose is transaction broadcasting, not full blockchain indexing
- Only user-submitted transactions need tracking for mining notifications
- `registered_transactions` + `metamorph.transactions` provide all necessary data
- Saves terabytes of database storage over time

**BUMP Merkle Proof Generation:**
When `storeAllBlockTransactions: false`, BlockTx uses an optimized approach for generating BUMP (BRC-74) merkle proofs:
- Stores complete merkle tree leaves (all tx hashes) in `blocks.merkle_leaves` BYTEA[] column
- Bitcoin P2P sends transaction hashes only (~32 bytes each), not full transaction data
- For 600M txs/block: 23 GB BYTEA[] vs 60 GB in `block_transactions` rows (60% storage savings)
- PostgreSQL TOAST handles large arrays via automatic chunking (1 GB chunks)
- Single sequential write (15-40 sec) vs 600M row inserts (7-14 min) = **20-50x faster**
- Complete merkle tree required for valid BUMP proofs (cannot reduce to partial tree)

When `storeAllBlockTransactions: true`, all transactions fill `block_transactions` table and Metamorph constructs BUMP proofs from that table instead (slower query, larger storage).

#### 2. `broadcastTransactions` (metamorph config)

Controls whether transactions are broadcast to the Bitcoin P2P network:

- **`true` (default)**: Transactions are broadcast to Bitcoin network peers
- **`false`**: Store-only mode - transactions stored but NOT broadcast

```yaml
metamorph:
  broadcastTransactions: false  # Set to false for store-only mode
```

**Use Cases:**
- **Broadcasting enabled (true)**: Normal transaction relay service
- **Broadcasting disabled (false)**: Testing, analytics, transaction storage without network propagation

### Updating and Rebuilding

After pulling updates from the repository:

```bash
git pull origin main
./build.sh
pm2 restart all
```

### Manual Service Commands

Start services individually:
```bash
pm2 start nats-server
pm2 start arc-api
pm2 start arc-metamorph
pm2 start arc-blocktx
pm2 start arc-callbacker
```

Monitor services:
```bash
pm2 monit              # Real-time monitoring
pm2 logs               # View all logs
pm2 logs arc-api       # View specific service logs
```

Restart services:
```bash
pm2 restart all        # Restart all services
pm2 restart arc-api    # Restart specific service
```

### Development Mode

For local development, use `config_local.yaml` and run services via command line:

```bash
# Start NATS
nats-server -js -p 4222 -m 8222 &

# Build the binary
go build -o arc ./cmd/arc/main.go

# Start individual services
./arc -config=config_local.yaml -k8s-watcher=false -api &
./arc -config=config_local.yaml -k8s-watcher=false -metamorph &
./arc -config=config_local.yaml -k8s-watcher=false -blocktx &
./arc -config=config_local.yaml -k8s-watcher=false -callbacker &
```

The `main.go` file accepts the following flags:

```shell
usage: arc [options]
where options are:

    -api=<true|false>
          whether to start ARC api server (default=true)

    -metamorph=<true|false>
          whether to start metamorph (default=true)

    -blocktx=<true|false>
          whether to start block tx (default=true)

    -k8s-watcher=<true|false>
          whether to start k8s-watcher (default=false for PM2 deployments)

    -callbacker=<true|false>
          whether to start callbacker (default=true)

    -config=/location
          path to config file (default='config.yaml')

    -dump_config=/file.yaml
          dump config to specified file and exit
```

**Note**: For PM2 deployments, set `-k8s-watcher=false` as Kubernetes features are not used.

## Microservices

The API http server as well as all gRPC servers of each service has dual-stack capability and thus listen on both IPv4 & IPv6 addresses.

### API

API is the REST API microservice for interacting with ARC. See the [API documentation](https://bitcoin-sv.github.io/arc/api.html) for more information.

The API takes care of authentication, validation, and sending transactions to Metamorph. The API talks to one or more Metamorph instances using client-based, round-robin load balancing.

To register a callback, the client must add the `X-CallbackUrl` header to the
request. The callbacker will then send a POST request to the URL specified in the header, with the transaction ID in
the body. See the [API documentation](https://bitcoin-sv.github.io/arc/api.html) for more information.

You can run the API like this:

```shell
go run cmd/arc/main.go -api=true
```

The only difference between the two is that the generic `main.go` starts the Go profiler, while the specific `cmd/api/main.go`
command does not.

#### Integration into an echo server

If you want to integrate the ARC API into an existing echo server, check out the
[examples](./examples) folder in the GitHub repo.

### Metamorph

Metamorph is a microservice that is responsible for processing transactions sent by the API to the Bitcoin network. It
takes care of re-sending transactions if they are not acknowledged by the network within a certain time period (60
seconds by default).

Metamorph is designed to be horizontally scalable, with each instance operating independently. As a result, they do not communicate with each other and remain unaware of each other's existence.

You can run metamorph like this:

```shell
go run cmd/arc/main.go -metamorph=true
```

#### Metamorph transaction statuses

Metamorph keeps track of the lifecycle of a transaction, and assigns it a status, which is returned in the `txStatus` field whenever the transaction is queried.
The following statuses are available:

| Status                   | Description                                                                                                                                                                                              |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `UNKNOWN`                | The transaction has been sent to metamorph, but no processing has taken place. This should never be the case, unless something goes wrong.                                                               |
| `QUEUED`                 | The transaction has been queued for processing.                                                                                                                                                          |
| `RECEIVED`               | The transaction has been properly received by the metamorph processor.                                                                                                                                   |
| `STORED`                 | The transaction has been stored in the metamorph store. This should ensure the transaction will be processed and retried if not picked up immediately by a mining node.                                  |
| `ANNOUNCED_TO_NETWORK`   | The transaction has been announced (INV message) to the Bitcoin network.                                                                                                                                 |
| `REQUESTED_BY_NETWORK`   | The transaction has been requested from metamorph by a Bitcoin node.                                                                                                                                     |
| `SENT_TO_NETWORK`        | The transaction has been sent to at least 1 Bitcoin node.                                                                                                                                                |
| `ACCEPTED_BY_NETWORK`    | The transaction has been accepted by a connected Bitcoin node on the ZMQ interface. If metamorph is not connected to ZMQ, this status will never by set.                                                 |
| `SEEN_IN_ORPHAN_MEMPOOL` | The transaction has been sent to at least 1 Bitcoin node but parent transaction was not found.                                                                                                           |
| `SEEN_ON_NETWORK`        | The transaction has been seen on the Bitcoin network and propagated to other nodes. This status is set when metamorph receives an INV message for the transaction from another node than it was sent to. |
| `DOUBLE_SPEND_ATTEMPTED` | The transaction is a double spend attempt. Competing transaction(s) will be returned with this status.                                                                                                   |
| `MINED_IN_STALE_BLOCK`   | The transaction has been mined into a block that became stale after a reorganisation of chain (reorg).                                                                                                   |
| `REJECTED`               | The transaction has been rejected by the Bitcoin network.                                                                                                                                                |
| `MINED`                  | The transaction has been mined into a block by a mining node.                                                                                                                                            |

The statuses have a difference between the codes in order to make it possible to add more statuses in between the existing ones without creating a breaking change.

#### Metamorph stores

Currently, Metamorph only offers one storage implementation which is Postgres.

Migrations have to be executed prior to starting Metamorph. For this you'll need the [go-migrate](https://github.com/golang-migrate/migrate) tool. Once `go-migrate` has been installed, the migrations can be executed as follows:
```bash
migrate -database "postgres://<username>:<password>@<host>:<port>/<db-name>?sslmode=<ssl-mode>"  -path internal/metamorph/store/postgresql/migrations  up
```

#### Connections to Bitcoin nodes

Metamorph can connect to multiple Bitcoin nodes, and will use a subset of the nodes to send transactions to. The other
nodes will be used to listen for transaction **INV** message, which will trigger the SEEN_ON_NETWORK status of a transaction.

The Bitcoin nodes can be configured in `config.yaml`.

#### Whitelisting

Metamorph is talking to the Bitcoin nodes over the p2p network. If metamorph sends invalid transactions to the
Bitcoin node, it will be **banned** by that node. Either make sure not to send invalid or double spend transactions through
metamorph, or make sure that all metamorph servers are **whitelisted** on the Bitcoin nodes they are connecting to.

#### ZMQ

Although not required, zmq can be used to listen for transaction messages (`hashtx`, `invalidtx`, `discardedfrommempool`).
This is especially useful if you are not connecting to multiple Bitcoin nodes, and therefore are not receiving INV
messages for your transactions. Currently, ARC can only detect whether a transaction was rejected e.g. due to double spending if ZMQ is connected to at least one node.

If you want to use zmq, you can set the `host.port.zmq` setting for the respective `peers` setting in the configuration file.

ZMQ does seem to be a bit faster than the p2p network, so it is recommended to turn it on, if available.

### BlockTx

BlockTx is a microservice that is responsible for processing blocks mined on the Bitcoin network, and for propagating
the status of transactions to Metamorph.

The main purpose of BlockTx is to de-duplicate processing of (large) blocks. As an incoming block is processed by BlockTx, each Metamorph is notified of transactions that they have registered an interest in.  BlockTx does not store the transaction data, but instead stores only the transaction IDs and the block height in which
they were mined. Metamorph is responsible for storing the transaction data.

You can run BlockTx like this:

```shell
go run cmd/arc/main.go -blocktx=true
```

#### BlockTx stores

Currently, BlockTx only offers one storage implementation which is Postgres.

Migrations have to be executed prior to starting BlockTx. For this you'll need the [go-migrate](https://github.com/golang-migrate/migrate) tool. Once `go-migrate` has been installed, the migrations can be executed as follows:
```bash
migrate -database "postgres://<username>:<password>@<host>:<port>/<db-name>?sslmode=<ssl-mode>"  -path internal/blocktx/store/postgresql/migrations  up
```

### Callbacker

Callbacker is a microservice that sends callbacks to a specified URL.

Callbacker is designed to be horizontally scalable, with each instance operating independently. As a result, they do not communicate with each other and remain unaware of each other's existence.

Callbacker receives messages from Metamorph over a NATS [message queue](#message-queue). Therefore, Callbacker requires the [message queue](#message-queue) to run together with ARC in order to function.

You can run Callbacker like this:

```shell
go run cmd/arc/main.go -callbacker=true
```

#### Callbacker stores

Currently, Callbacker only offers one storage implementation which is Postgres.

Migrations have to be executed prior to starting Callbacker. For this you'll need the [go-migrate](https://github.com/golang-migrate/migrate) tool. Once `go-migrate` has been installed, the migrations can be executed as follows:
```bash
migrate -database "postgres://<username>:<password>@<host>:<port>/<db-name>?sslmode=<ssl-mode>"  -path internal/callbacker/store/postgresql/migrations  up
```

## K8s-Watcher

If ARC runs on a Kubernetes cluster, then the K8s-Watcher can be run as a safety measure in case that graceful shutdown was not successful. K8s-watcher keeps an up-to-date list of `callbacker` and `metamorph` pods. It sends this list in intervals to each of the service using the `UpdateInstances` rpc call. Both `callbacker` and `metamorph` run any remaining cleanup procedures.

The K8s-Watcher can be started as follows

```shell
go run cmd/arc/main.go -k8s-watcher=true
```

## Message Queue

For the asynchronous communication between services a message queue is used. Currently, the only available implementation of that message queue uses [NATS](https://nats.io/). A message queue of this type has to run in order for ARC to run. Currently, ARC requires to the message queue to run with [Jetstream](https://docs.nats.io/nats-concepts/jetstream) enabled. Future versions of ARC may allow running with Jetstream disabled or without a message queue at all.

One instance where the message queue is used is the communication between Metamorph & Blocktx service. Metamorph publishes new transactions to the message queue and BlockTx subscribes to the message queue, receive the transactions and stores them. Once BlockTx finds these transactions have been mined in a block it updates the block information and publishes the block information to the message queue. Metamorph subscribes to the message queue and receives the block information and updates the status of the transactions.

![Message Queue](./doc/message_queue.png)

## Broadcaster-cli

Please see [README.md](./cmd/broadcaster-cli/README.md) for more details

## Tests
### Unit tests

In order to run the unit tests do the following
```
task test
```

### Integration tests

Integration tests of the postgres database need docker installed to run them. If `colima` implementation of Docker is being used on macOS, the `DOCKER_HOST` environment variable may need to be given as follows
```bash
DOCKER_HOST=unix:///Users/<username>/.colima/default/docker.sock task test
```
These integration tests can be excluded from execution with `go test ./...` by adding the `-short` flag like this `go test -short ./...`.

### E2E tests

The end-to-end tests are located in the folder `test`. Docker needs to be installed in order to run them. End-to-end tests can be run locally together with ARC, 3 nodes and all other external services like databases using the provided docker-compose file.
The tests can be executed like this:
```
task run_e2e_tests
```

The [docker-compose](./docker-compose.yaml) file also shows the minimum setup that is needed for ARC to run.

## Monitoring

### Prometheus

Prometheus can collect ARC metrics. It improves observability in production and enables debugging during development and deployment. As Prometheus is a very standard tool for monitoring, any other complementary tool such as Grafana and others can be added for better data analysis.

Prometheus periodically polls the system data by querying specific urls.

ARC can expose a Prometheus endpoint that can be used to monitor the servers. Set the `prometheusEndpoint` setting in the settings file to activate prometheus. Normally you would want to set this to `/metrics`.

The Prometheus endpoint can be configured in `config.yaml`:

```yaml
prometheus:
  enabled: false # if true, then prometheus metrics are enabled
  endpoint: /metrics # endpoint for prometheus metrics
  addr: :2112 # port for serving prometheus metrics
```

### Profiler

Each service runs a http profiler server if it is configured in `config.yaml`. In order to access it, a connection can be created using the Go `pprof` [tool](https://pkg.go.dev/net/http/pprof). For example to investigate the memory usage
```bash
go tool pprof http://localhost:9999/debug/pprof/allocs
```
Then type `top` to see the functions which consume the most memory. Find more information [here](https://go.dev/blog/pprof).

### Tracing

Currently, the traces are exported only in [open telemtry protocol (OTLP)](https://opentelemetry.io/docs/specs/otel/protocol/) on the gRPC endpoint. This endpoint URL of the receiving tracing backend (e.g. [Jaeger](https://www.jaegertracing.io/), [Grafana Tempo](https://grafana.com/oss/tempo/), etc.) can be configured with the respective `tracing.dialAddr` setting.

Tracing can be configured in `config.yaml`:

```yaml
  tracing:
    enabled: true # is tracing enabled
    dialAddr: http://localhost:4317 # address where traces are exported to
    sample: 100 # percentage of the sampling
```

## Building ARC

For building the ARC binary, there is a make target available. ARC can be built for Linux OS and amd64 architecture using

```
task build_release
```

Once this is done additionally a docker image can be built using

```
task build_docker
```

### Generate grpc code

GRPC code are generated from protobuf definitions. In order to generate the necessary tools need to be installed first by running
```
task install_gen
```
Additionally, [protoc](https://grpc.io/docs/protoc-installation/) needs to be installed.

Once that is done, GRPC code can be generated by running
```
task gen
```

### Generate REST API

The rest api is defined in a [yaml file](./pkg/api/arc.yaml) following the OpenAPI 3.0.0 specification. Before the rest API can be generated install the necessary tools by running
```
task install_gen
```
Once that is done, the API code can be generated by running
```
task api
```

### Generate REST API documentation
Before the documentation can be generated [swagger-cli](https://apitools.dev/swagger-cli/) and [widdershins](https://github.com/Mermade/widdershins) need to be installed.

Once that is done the documentation can be created by running
```
task docs
```

## Acknowledgements
Special thanks to [rloadd](https://github.com/rloadd/) for his inputs to the documentation of ARC.

## Contribution Guidelines

We're always looking for contributors to help us improve the project. Whether it's bug reports, feature requests, or pull requests - all contributions are welcome.

1. **Fork & Clone**: Fork this repository and clone it to your local machine.
2. **Set Up**: Run `task deps` to install all dependencies.
3. **Make Changes**: Create a new branch and make your changes.
4. **Test**: Ensure all tests pass by running `task test` and `task run_e2e_tests`.
5. **Commit**: Commit your changes and push to your fork.
6. **Pull Request**: Open a pull request from your fork to this repository.

For more details, check the [contribution guidelines](./CONTRIBUTING.md).

For information on past releases, check out the [changelog](./CHANGELOG.md).

## Support & Contacts

For questions, bug reports, or feature requests, please open an issue on GitHub.
