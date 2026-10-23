# DEVCON

A containerized, batteries-included development environment. One image gives you a browser-based VS Code, an AI coding agent (Mistral Vibe), a curated shell, and language toolchains — all running as an unprivileged user inside an optional microVM.

---

## What

DEVCON is a [Podman](https://podman.io/) container image that packages a complete, opinionated dev setup:

| Layer | What's inside |
|---|---|
| **Editor** | [code-server](https://github.com/coder/code-server) — VS Code in the browser, with a pre-configured settings profile (vim keybindings, ligature fonts, Selenized Light theme, format-on-save, relative line numbers) |
| **AI agent** | [Mistral Vibe](https://github.com/mistralai/vibe) — a CLI coding agent, wired into code-server via the ACP protocol so it appears as a chat panel inside the editor |
| **Shell** | [fish](https://fishshell.com/) with vi keybindings, a custom two-line prompt (git status, venv, battery, background jobs), and convenience aliases |
| **Toolchains** | Rust (rustc, cargo, rustfmt, clippy, rust-src), Flutter/Dart SDK, Go, Python (via `uv`), C/C++ (clang, cmake, lld, lldb) |
| **Utilities** | `bat`, `fd`, `rg`, `jq`, `tree`, PostgreSQL client libs, and more |
| **Extensions** | Pre-installed VS Code extensions for Python, Rust, Go, Dart, SQL (PostgreSQL/SQLite), TOML, YAML, SARIF, and more |

The image is built from `quay.io/fedora/fedora-minimal` and hardened: the root account is disabled and expired, and the container runs as an unprivileged user (`devcon`, UID 1000).

## Why

- **Isolated.** On Linux, the example compose file runs the container inside a [krun](https://github.com/containers/libkrun) microVM (`runtime: krun`), so your host is never exposed to container processes.
- **Reproducible.** The entire environment — editor, shell, toolchains, extensions, agent, settings — is defined in one `Containerfile`. No "works on my machine."
- **Secrets stay out of the image.** Git credentials, your git identity, and the Mistral API key are injected at runtime via Podman secrets, not baked in.
- **AI-assisted by default.** Mistral Vibe is pre-configured and surfaced inside code-server, so you can chat with an agent that has full access to your project files and terminal.
- **Opinionated defaults.** Every setting (editor, shell, agent permissions) lives in plain config files under `code-server/`, `fish/`, and `mistral-vibe/` — fork and tweak freely.

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

**[`example/devcon.env`](example/devcon.env)** — environment variables consumed by the container entrypoint.

**[`example/devcon.yaml`](example/devcon.yaml)** — a `podman-compose` file that starts the container.

Key points:

- **`runtime: krun`** — runs the container inside a lightweight microVM for hardware-level isolation (Linux only).
- **`secrets`** — four secrets are mounted into the container at startup. The entrypoint reads them to configure git identity, git credential helper, and the Mistral Vibe API key.
- **`DEVCON_GIT_REPO` / `DEVCON_WORK_DIR`** — the entrypoint clones this repo into `~/project` on the first start.
- **`ports`** — code-server is bound to `127.0.0.1:8000` on the host; nothing is exposed externally. Host-side port number is of your choice.

Start it:

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

---

## Repository layout

```
├── bin/entrypoint           # container startup script (git config, clone, password)
├── code-server/             # code-server config, settings, fonts
├── example/
│   ├── devcon.yaml          # podman-compose file (edit for your project)
│   └── devcon.env           # environment variables for the entrypoint (edit for your project)
├── fish/                    # fish shell config (prompt, aliases, vi mode)
├── mistral-vibe/            # Mistral Vibe agent configuration
├── build                    # helper script: podman build -t devcon .
└── Containerfile            # image definition
```

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
