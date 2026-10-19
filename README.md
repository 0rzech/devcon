# DEVCON

A containerized, batteries-included development environment. One image gives you a browser-based VS Code, an AI coding agent (Mistral Vibe), a curated shell, and language toolchains - all running as an unprivileged user inside an optional microVM.

---

## What

DEVCON is a [Podman](https://podman.io/) container image that packages opinionated dev setup:

* **Editor** - [code-server](https://github.com/coder/code-server) - text editor in the browser, with pre-configured settings
* **AI agent** - [Mistral Vibe](https://github.com/mistralai/vibe) - a coding agent available as a CLI and as an ACP process wired into code-server
* **Shell** - [fish](https://fishshell.com/) with vi keybindings and a custom two-line prompt
* **Toolchains** - Rust and Dart/Flutter
* **Utilities** - `bat`, `fd`, `rg`, `jq`, `tree`, PostgreSQL client libs etc.
* **Extensions** - Pre-installed OpenVSX extensions for Python, Rust, Go, Dart, SQL (PostgreSQL/SQLite), TOML, YAML, SARIF etc.

Hardened image: the root account is disabled and expired, and the container runs as an unprivileged user (`devcon`, UID 1000).

## Why

**Isolation.** On Linux, the example compose file runs the container inside a [krun](https://github.com/containers/libkrun) microVM, so your host is never exposed to container processes.

## How

### 1. Build the image

```sh
./build
```

This runs `podman build -t devcon .` using the `Containerfile` at the repo root.

### 2. Prepare secrets

Create the following Podman secrets (names and values are examples):

```sh
podman secret create some-git-user-name-secret   <<< "Your Name"
podman secret create some-git-user-email-secret  <<< "you@example.com"
podman secret create project-credentials         <<< "https://user:pat@github.com"
podman secret create mistral-api-key             <<< "MISTRAL_API_KEY='your-mistral-api-key'"
```

Mount bind them to appropriate in-container names: `git-user-name`, `git-user-email`, `/home/devcon/.config/git/credentials` and `/home/devcon/.config/vibe/.env`.

### 3. Configure and run

Copy the files in [`example/`](example/) and edit them for your project.

**[`example/devcon.env`](example/devcon.env)** - environment variables consumed by the container entrypoint.

**[`example/devcon.yaml`](example/devcon.yaml)** - a `podman-compose` file that starts the container.

- **`runtime: krun`** - runs the container inside a lightweight microVM for hardware-level isolation (Linux only).
- **`secrets`** - four secrets are mounted into the container at startup. The entrypoint reads them to configure git identity, git credential helper, and the Mistral Vibe API key.
- **`DEVCON_GIT_REPO` / `DEVCON_WORK_DIR`** - the entrypoint clones this repo into `~/project` on the first start.
- **`ports`** - code-server is bound to `127.0.0.1:8000` on the host; nothing is exposed externally. Host-side port number is of your choice.

Run the container:

```sh
podman-compose -f example/devcon.yaml up -d
```

### 4. Connect

On the first start, the entrypoint generates a random password for code-server and prints a banner like this to the container logs:

```
<<< DEVCON >>>

http://localhost:8000/?folder=/home/devcon/project

<random-password>

<<< ====== >>>
```

Grab the URL and password from the logs:

```sh
podman logs project
```

or view them within [Podman Desktop](https://podman-desktop.io/).

Then open the URL in your browser and log in with the password. Your project is already cloned and open in the editor sidebar, and Mistral Vibe is available in the chat panel.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
