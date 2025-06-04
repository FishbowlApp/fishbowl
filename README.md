# [Octocon](https://octocon.app) backend

**Octocon is the modern, all-in-one toolkit for people with DID and OSDD to manage their disorder and express themselves.**

It's also a
wacky monolith built with [Elixir](https://elixir-lang.org/), [Phoenix](https://www.phoenixframework.org/),
and [Postgres](https://www.postgresql.org/), deployed on a combination of [cloud infrastructure](https://fly.io/) and unmanaged, bare-metal hardware!

## Project structure 
This repository contains the backend code for Octocon, which is structured into three main components:
- **octocon**: The core Elixir application that handles the business logic, data processing, clustering, node differentiation, and other backend functionalities.
- **octocon-web**: The Phoenix web application that serves the REST API, metrics, and admin dashboard.
- **octocon-discord**: The Discord bot that serves as an alternative interface for interacting with the Octocon platform, including "proxying" as alters.


## Distributed monolith
Octocon is designed as a distributed monolith, meaning that while the components have a clear separation of concerns, they share a common codebase which is compiled and deployed as one.

Octocon is generally run in a cluster of nodes, which are designed to be globally distributed across the world. One "primary region" interfaces with the read-write database and runs the Discord bot, while "auxiliary regions" interface with read-only replicas of the database. This allows for low-latency access to the data from anywhere in the world; write operations on auxiliaries are proxied through RPC to the primary region.

When not running on Fly.io, an Octocon node knows its role in the overall cluster through an environment variable (`NODE_GROUP`), which determines which parts of the supervision tree it will run, and how it will advertise itself to its peers.

By default, Octocon is configured to discover other nodes using the [libcluster](https://github.com/bitwalker/libcluster) library with a custom Tailscale strategy. All that is necessary is for each node to form a Distributed Erlang cluster; Octocon has internal logic to determine and cache each node's role in the cluster through an RPC communication step.

There are 3 node groups:
- `primary`: A node running in the primary region, which interfaces with the read-write database and runs Discord shards. Other nodes proxy their database writes to a `primary` node.
- `auxiliary`: A node running in an auxiliary region, which interfaces with a read-only replica of the database. These nodes are largely only responsible for serving HTTP requests to the API.
- `sidecar`: A node responsible for isolating CPU-bound tasks from the rest of the cluster, such as image processing and heavy encryption tasks. **At least one** sidecar must be present in the cluster.

**Note**: Running multiple `primary` nodes is heavily experimental and not currently recommended - our Discord library (Nostrum) still doesn't behave well in this type of distributed environment.
## Configuration & integrations
Every Octocon node must be configured with a set of environment variables to function properly. These variables are used to connect to the database, configure the Discord bot, and set up other integrations, such as cloud object storage.

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
- `S3_ACCESS_HOST` - The URL assets are stored at (e.g. `https://cdn.octocon.app`).
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