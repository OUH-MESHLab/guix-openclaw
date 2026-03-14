# guix-openclaw

A [Guix](https://guix.gnu.org) channel that provides declarative, reproducible
package and service definitions for [OpenClaw](https://github.com/openclaw/openclaw)
— a self-hosted multi-channel AI gateway that routes LLM conversations through
messaging platforms (Telegram, WhatsApp, Slack, Discord, Signal, Matrix, IRC,
and others).

## Contents

| Module                                        | What it provides                                                              |
|-----------------------------------------------|-------------------------------------------------------------------------------|
| `(guix-openclaw packages openclaw)`           | The `openclaw` package                                                        |
| `(guix-openclaw packages node-runtime)`       | `node-22.16.0` (minimum Node required by openclaw)                            |
| `(guix-openclaw packages node-openclaw-deps)` | ~810 generated npm dependency packages                                        |
| `(guix-openclaw services openclaw)`           | `openclaw-service-type` (system) and `home-openclaw-service-type` (Guix Home) |

---

## Adding the channel

Add this channel to `~/.config/guix/channels.scm`:

```scheme
(cons* (channel
        (name 'guix-openclaw)
        (url "https://github.com/OUH-MESHLab/guix-openclaw")
        (branch "main"))
       %default-channels)
```

Then pull:

```bash
guix pull
```

---

## Quick start — `guix shell` container

The fastest way to try OpenClaw locally is a `guix shell` container.  No
installation, no system changes, full network isolation.

### 1. Create a state directory and seed config

```bash
mkdir -p ~/.openclaw-dev

cat > ~/.openclaw-dev/openclaw.json << 'EOF'
{
  gateway: {
    mode: "local",
    port: 18789,
    bind: "127.0.0.1",
    auth: { mode: "none" },
    tailscale: { mode: "off" }
  },
  logging: { level: "info" }
}
EOF
```

`auth: { mode: "none" }` is convenient for local dev.  For anything exposed
further, use `"token"` and set `OPENCLAW_GATEWAY_TOKEN` in your environment.

### 2. Launch the gateway

```bash
OPENCLAW_STATE_DIR=/var/lib/openclaw \
OPENCLAW_CONFIG_PATH=/var/lib/openclaw/openclaw.json \
OPENCLAW_GATEWAY_PORT=18789 \
OPENCLAW_LOG_LEVEL=info \
OPENCLAW_NO_RESPAWN=1 \
ANTHROPIC_API_KEY=sk-ant-... \
guix shell -L . -C --network \
  --share="$HOME/.openclaw-dev=/var/lib/openclaw" \
  --expose=/etc/ssl \
  openclaw \
  -- openclaw gateway
```

Flag summary:

| Flag                | Purpose                                                                               |
|---------------------|---------------------------------------------------------------------------------------|
| `-C`                | Isolated container — no host PATH leakage                                             |
| `--network`         | Shares the host network namespace; the gateway binds to `127.0.0.1:18789` on the host |
| `--share=SRC=DST`   | Bind-mounts your local state dir read-write at the path openclaw expects              |
| `--expose=/etc/ssl` | Makes CA certificates available for outbound TLS to LLM APIs                          |

### 3. Check it is up

```bash
curl -s http://127.0.0.1:18789/health
```

### 4. Open an interactive shell inside the container

Useful for running `openclaw config set`, inspecting state, or debugging:

```bash
guix shell -L . -C --network \
  --share="$HOME/.openclaw-dev=/var/lib/openclaw" \
  --expose=/etc/ssl \
  openclaw bash coreutils \
  -- bash
```

Then inside the container:

```bash
openclaw --version
openclaw gateway &
openclaw config set agent.model anthropic/claude-opus-4-6
```

---

## Guix System service

For a server or NAS deployment managed by `guix system reconfigure`.

### `operating-system` snippet

```scheme
(use-modules (gnu)
             (guix-openclaw services openclaw))

(operating-system
  ;; ... your existing config ...
  (services
   (append
    (list
     (service openclaw-service-type
              (openclaw-configuration
               (port         18789)
               (bind-address "127.0.0.1")    ; expose via nginx or Tailscale
               (auth-mode    'token)
               (environment-file "/etc/openclaw/secrets.env")
               (log-level    "info"))))
    %desktop-services)))
```

### Service configuration fields

| Field              | Default               | Description                                                                 |
|--------------------|-----------------------|-----------------------------------------------------------------------------|
| `openclaw`         | `openclaw` package    | Package to use                                                              |
| `user`             | `"openclaw"`          | System user (created automatically)                                         |
| `group`            | `"openclaw"`          | System group (created automatically)                                        |
| `state-directory`  | `"/var/lib/openclaw"` | Persistent state: database, sessions, uploads                               |
| `port`             | `18789`               | TCP port the gateway listens on                                             |
| `bind-address`     | `"127.0.0.1"`         | Interface to bind; keep loopback and reverse-proxy in front                 |
| `auth-mode`        | `'token`              | `'token`, `'password`, or `'none`                                           |
| `environment-file` | `#f`                  | Path to a `KEY=value` secrets file (see below)                              |
| `log-level`        | `"info"`              | `"trace"`, `"debug"`, `"info"`, `"warn"`, or `"error"`                      |
| `config-file`      | `#f`                  | `file-like` object for a full `openclaw.json`; `#f` generates a minimal one |

### Secrets file (`environment-file`)

API keys and channel tokens must **not** go into the Guix store.  Put them in
a file readable only by the `openclaw` user and point `environment-file` at it.

```bash
# /etc/openclaw/secrets.env
# chmod 640, owned by root:openclaw

ANTHROPIC_API_KEY=sk-ant-...
OPENCLAW_GATEWAY_TOKEN=change-me-to-a-long-random-string

# Channel credentials (examples)
channels__telegram__botToken=123456:ABCdef...
channels__slack__botToken=xoxb-...
channels__discord__token=MTA...
```

Create the file before the first `guix system reconfigure`:

```bash
sudo mkdir -p /etc/openclaw
sudo touch /etc/openclaw/secrets.env
sudo chmod 640 /etc/openclaw/secrets.env
sudo chown root:openclaw /etc/openclaw/secrets.env
sudoedit /etc/openclaw/secrets.env
```

### First-run behaviour

On the first `guix system reconfigure`, the activation script:

1. Creates `/var/lib/openclaw` owned by the `openclaw` user (mode `750`)
2. Seeds `/var/lib/openclaw/openclaw.json` from the generated (or supplied) config

On subsequent reconfigures the config is **never overwritten**, so changes made
via `openclaw config set` survive.

### Shepherd management

```bash
# Check status
sudo herd status openclaw

# View logs
sudo herd output openclaw
# or
sudo tail -f /var/lib/openclaw/openclaw.log

# Restart after editing secrets.env
sudo herd restart openclaw

# Stop / start
sudo herd stop openclaw
sudo herd start openclaw
```

---

## Guix Home service

For a personal workstation managed by `guix home reconfigure`.  State lives in
`$HOME/.openclaw`; no root required.

### `home-environment` snippet

```scheme
(use-modules (gnu home)
             (gnu home services)
             (guix-openclaw services openclaw))

(home-environment
  ;; ... your existing config ...
  (services
   (list
    (service home-openclaw-service-type
             (home-openclaw-configuration
              (port             18789)
              (bind-address     "127.0.0.1")
              (auth-mode        'token)
              (environment-file (string-append
                                 (getenv "HOME")
                                 "/.openclaw/secrets.env"))
              (log-level        "info"))))))
```

### Home service configuration fields

Same as the system service minus `user`, `group`, and `state-directory`.

| Field              | Default            | Description                        |
|--------------------|--------------------|------------------------------------|
| `openclaw`         | `openclaw` package | Package to use                     |
| `port`             | `18789`            | TCP port                           |
| `bind-address`     | `"127.0.0.1"`      | Interface to bind                  |
| `auth-mode`        | `'token`           | `'token`, `'password`, or `'none`  |
| `environment-file` | `#f`               | Path to a `KEY=value` secrets file |
| `log-level`        | `"info"`           | Log verbosity                      |
| `config-file`      | `#f`               | Full `openclaw.json` override      |

### Shepherd management (home)

```bash
# Check status
herd status openclaw

# View logs
tail -f ~/.openclaw/openclaw-$(date +%Y-%m-%d).log

# Restart
herd restart openclaw
```

---

## `openclaw.json` template

This is the minimal config that the service generates automatically when
`config-file` is `#f`.  Copy, adjust, and pass it as `config-file` if you
want full declarative control.

```json5
{
  gateway: {
    // "local" — standard Node process (default for Guix deployments)
    mode: "local",

    port: 18789,
    bind: "127.0.0.1",

    auth: {
      // "token"    — bearer token (set OPENCLAW_GATEWAY_TOKEN in secrets.env)
      // "password" — username/password login
      // "none"     — no auth (local dev only)
      mode: "token"
    },

    // Tailscale is a separate daemon with its own Guix service.
    // Keep this off and use `tailscale serve` if you want Tailscale exposure.
    tailscale: { mode: "off" }
  },

  logging: {
    // "trace" | "debug" | "info" | "warn" | "error"
    level: "info"
  }

  // Everything below is application-layer config managed by `openclaw config set`
  // or edited in place.  Leave it out of the declarative config — the service
  // seeds the file once and never overwrites it.
  //
  // agent: {
  //   model: "anthropic/claude-opus-4-6"
  // },
  //
  // channels: {
  //   telegram: { botToken: "${TELEGRAM_BOT_TOKEN}" },
  //   slack:    { botToken: "${SLACK_BOT_TOKEN}", appToken: "${SLACK_APP_TOKEN}" }
  // }
}
```

To use a custom config file with the system service:

```scheme
(service openclaw-service-type
  (openclaw-configuration
    (config-file (local-file "openclaw.json"))))
```

---

## Design notes

### What belongs in the service record vs what does not

The service record controls the **daemon layer** only:

- Process lifecycle (user, group, state directory)
- Network binding (port, address)
- Authentication mode
- Log level
- Secrets injection (environment file)

The following are **intentionally excluded**:

| Concern                      | Why excluded                                         | Correct approach                                 |
|------------------------------|------------------------------------------------------|--------------------------------------------------|
| Tailscale                    | Has its own Guix service                             | Use `tailscale-service-type` + `tailscale serve` |
| Channel credentials          | Sensitive, too numerous to model as fields           | Put in `environment-file`                        |
| LLM API keys                 | Same                                                 | Same                                             |
| Agent config, routing, tools | Application-layer, not daemon-layer                  | `openclaw config set` or `config-file`           |
| Docker/OCI                   | OpenClaw should not manage its own container runtime | Use `oci-container-service-type` if needed       |

---

## Building from source

```bash
# Clone the channel
git clone https://github.com/YOUR_USERNAME/guix-openclaw
cd guix-openclaw

# Build the main package
guix build -L . openclaw

# Build a specific npm dependency
guix build -L . node-sharp

# Run in a container without installing
guix shell -L . -C --network openclaw -- openclaw --version

# Check the service module loads
guix repl -L .
,use (guix-openclaw services openclaw)
openclaw-service-type
```
