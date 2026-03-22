# [Fishbowl](https://fishbowl.systems) backend

**Fishbowl is the modern, all-in-one toolkit for people with DID and OSDD to manage their disorder and express themselves.**

It's also a
wacky monolith built with [Elixir](https://elixir-lang.org/), [Phoenix](https://www.phoenixframework.org/),
and [ScyllaDB](https://www.scylladb.com/), deployed on a combination of [cloud infrastructure](https://fly.io/) and bare-metal hardware!

## Project structure 
This repository contains the backend code for Fishbowl, which is structured into three main components:
- **fishbowl**: The core Elixir application that handles the business logic, data processing, clustering, node differentiation, and other backend functionalities.
- **fishbowl-web**: The Phoenix web application that serves the REST API, metrics, and admin dashboard.
- **fishbowl-discord**: The Discord bot that serves as an alternative interface for interacting with the Fishbowl platform, including "proxying" as alters.

## Development setup

To set up a development environment for Fishbowl, you'll need to have the following prerequisites installed on a Unix-like operating system or WSL:
- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/install/)
- Git

Once installed, follow these steps to set up your development environment:
1. Clone the repository:
   ```bash
   git clone https://github.com/FishbowlApp/fishbowl
   cd fishbowl
   ```

2. Run the provided setup script:
   ```bash
   ./dev/setup.sh
   ```
   This script will ensure your system is configured correctly, build the necessary Docker images, install dependencies, and perform database migrations.

3. Start the development environment:
   ```bash
   ./dev/bin/iex
   ```
    This command will launch an interactive Elixir shell running the Fishbowl application inside a Docker container.

## Contributing

We welcome contributions to Fishbowl! If you'd like to contribute, please follow these steps:
1. Fork the repository on GitHub and create a new branch for your feature or bug fix.
2. Use [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) for your commit messages.
3. Run `mix format` then `mix lint` before submitting a PR to ensure code quality.
4. Submit a pull request to this repository for review.

While we respect your time, please note that not every contribution will be accepted; certain features may not align with our project's goals or privacy/security standards. If you'd like to contribute a new feature, your best bet is to reach out to us in the `#development` channel on our [Discord server](https://discord.neocon.attiplayz.dev) first to discuss its feasibility. Alternatively, we welcome PRs implementing accepted suggestions posted on the issues page.)

## Deployment structure
Fishbowl is designed as a distributed monolith, meaning that while the components have a clear separation of concerns, they share a common codebase which is compiled and deployed as one executable.

Fishbowl is generally run in a cluster of nodes, which are designed to be globally distributed across the world. One "primary" node interfaces with a generally larger database instance and runs the Discord bot, while "auxiliary" nodes interface with smaller database instances. This allows for low-latency access to the data from anywhere in the world.

When not running on Fly.io, an Fishbowl node knows its role in the overall cluster through an environment variable (`NODE_GROUP`), which determines which parts of the supervision tree it will run, and how it will advertise itself to its peers.

In production, Fishbowl is configured to discover other nodes using the [libcluster](https://github.com/bitwalker/libcluster) library with a custom Tailscale strategy. All that is necessary is for each node to form a Distributed Erlang cluster; Fishbowl has internal logic to determine and cache each node's role in the cluster through an RPC communication step.

There are 3 node groups:
- `primary`: A node running in the primary region, which interfaces with a larger database instance, runs Discord shards, and handles certain types of global state. Other nodes proxy some requests to a `primary` node.
- `auxiliary`: A node running in an auxiliary region, which interfaces with a smaller database instance. These nodes are largely only responsible for serving HTTP requests to the API.
- `sidecar`: A node responsible for isolating CPU-bound tasks from the rest of the cluster, such as image processing and heavy encryption tasks. Ideally, **at least one** sidecar should be present in the cluster. If no sidecar is present, nodes will run these tasks themselves.

**Note**: Running multiple `primary` nodes is heavily experimental and not currently recommended - our Discord library (Nostrum) still doesn't behave well in this type of distributed environment.

## Configuration & integrations

Every Fishbowl node must be configured with a set of environment variables to function properly. These variables are used to connect to the database, configure the Discord bot, and set up other integrations, such as cloud object storage.

### OAuth
- `APPLE_TEAM_ID` - Used for Sign in with Apple integration.
- `APPLE_CLIENT_ID` - Used for Sign in with Apple integration.
- `APPLE_PRIVATE_KEY_ID` - Used for Sign in with Apple integration.
- `APPLE_PRIVATE_KEY` - Used for Sign in with Apple integration. (PEM in base64 format).
- `GOOGLE_CLIENT_ID` - Used for Google OAuth integration.
- `GOOGLE_CLIENT_SECRET` - Used for Google OAuth integration.
- `DISCORD_CLIENT_ID` - Used for Discord OAuth integration.
- `DISCORD_CLIENT_SECRET` - Used for Discord OAuth integration.
### Discord
- `DISCORD_TOKEN` - The bot token for the Discord bot.
### Security
- `SECRET_KEY_BASE` - Used by Phoenix to sign/encrypt cookies and other secrets; generate with `mix phx.gen.secret`.
- `ENCRYPTION_PEPPER` - Static server-side pepper used during the end-to-end encryption process.
- `GUARDIAN_SECRET_KEY` - Used by Guardian (OAuth) for JWT authentication.
- `ENCRYPTION_PRIVATE_KEY` - The private key used for end-to-end encryption of user data (PEM in base64 format).
### Admin Dashboard
- `ADMIN_USERNAME` - The username for the admin dashboard.
- `ADMIN_PASSWORD` - The password for the admin dashboard (HTTP Basic auth).
### Storage (S3-compatible)
- `S3_ACCESS_HOST` - The URL assets are stored at (e.g. `https://neocon-cdn.attiplayz.dev`).
- `S3_ASSET_HOST` - Same as above.
- `S3_HOST` - The storage host (e.g. `xyz.r2.cloudflarestorage.com`).
- `S3_REGION` - The region of the storage bucket (e.g. `auto` for Cloudflare R2).
- `S3_ACCESS_KEY_ID` - The access key ID for the S3-compatible storage service.
- `S3_SECRET_ACCESS_KEY` - The secret access key for the S3-compatible storage service.
- `S3_BUCKET_NAME` - The name of the bucket to store assets in.
### Monitoring/o11y
- `SENTRY_DSN` - The Sentry DSN for error tracking.
- `GRAFANA_HOST` - The URL of the Grafana instance to automatically upload dashboards.
- `GRAFANA_TOKEN` - Auth token for Grafana API access.
### Node configuration
- `NODE_GROUP` - The group this node belongs to (`primary`, `auxiliary`, or `sidecar`).
- `PRIMARY_NODE_COUNT` - Number of primary nodes in the cluster (**values other than 1 are experimental**).
- `POOL_SIZE` - Size of the database connection pool.
- `PORT` - Port to run the Phoenix web server on.
- `TAILSCALE_API_AUTHKEY` - When present, enables Tailscale-based clustering using the provided auth key.
- `NODE_LIST` - When present, enables static clustering with the provided comma-separated list of node IPs.
If neither `TAILSCALE_API_AUTHKEY` nor `NODE_LIST` are present, a single-node cluster is assumed, which will run as a `primary` node.
