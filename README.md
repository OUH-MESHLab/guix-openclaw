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
chmod 700 ~/.openclaw-dev

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

`auth: { mode: "none" }` is safe for local dev (loopback only).  For anything
exposed further, use `"token"` — see [Secrets management](#secrets-management).

### 2. Launch the gateway

Store your API key in [GNU Pass](https://www.passwordstore.org/) so it never
appears in shell history:

```bash
pass insert openclaw/anthropic-key
```

Then launch, injecting the key from pass at invocation time:

```bash
ANTHROPIC_API_KEY=$(pass show openclaw/anthropic-key) \
guix shell -L . -C --pure --network \
  --preserve='^ANTHROPIC_API_KEY$' \
  --share="$HOME/.openclaw-dev=/var/lib/openclaw" \
  --expose=/etc/ssl/certs \
  openclaw \
  -- env \
     OPENCLAW_STATE_DIR=/var/lib/openclaw \
     OPENCLAW_CONFIG_PATH=/var/lib/openclaw/openclaw.json \
     OPENCLAW_GATEWAY_PORT=18789 \
     OPENCLAW_LOG_LEVEL=info \
     OPENCLAW_NO_RESPAWN=1 \
     openclaw gateway
```

> **If you see `Missing config` on startup**, your existing `openclaw.json`
> does not contain `gateway.mode`.  Either re-run step 1 (which overwrites the
> file) or append `--allow-unconfigured` to the last line.

Flag summary:

| Flag                      | Purpose                                                                               |
|---------------------------|---------------------------------------------------------------------------------------|
| `-C`                      | Isolated container — no host filesystem or PATH leakage                               |
| `--pure`                  | Clears all inherited env vars; only `--preserve`d ones enter the container            |
| `--preserve=REGEXP`       | Passes matching env vars from the outer environment into the container                |
| `--network`               | Shares the host network namespace; the gateway binds to `127.0.0.1:18789` on the host |
| `--share=SRC=DST`         | Bind-mounts your local state dir read-write at the path openclaw expects              |
| `--expose=/etc/ssl/certs` | Makes CA certificates available for outbound TLS to LLM APIs                         |

### 3. Check it is up

```bash
curl -s http://127.0.0.1:18789/health
```

### 4. Open the web UI

```
http://127.0.0.1:18789/
```

> If you see "Unauthorized" after previously running with `auth.mode = "token"`,
> your browser has a cached response.  Hard-refresh (`Ctrl+Shift+R`) or clear
> site data for `127.0.0.1:18789` in your browser's dev tools.

### 5. Open an interactive shell inside the container

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

## Secrets management

OpenClaw needs several sensitive values at runtime: LLM API keys, a gateway
auth token, and per-channel bot tokens.  **None of these should appear in shell
history, the Guix store, or world-readable files.**  The recommended tool is
[GNU Pass](https://www.passwordstore.org/), which stores everything
GPG-encrypted in `~/.password-store/`.

### Initial pass setup (once)

```bash
# Initialise with your GPG key ID (skip if already done)
pass init your-gpg-key-id@example.com
```

### Storing OpenClaw secrets

```bash
# LLM provider key
pass insert openclaw/anthropic-key

# Gateway bearer token (generate a random one)
pass insert openclaw/gateway-token
# Tip: openssl rand -hex 32 | pass insert -e openclaw/gateway-token

# Channel bot tokens
pass insert openclaw/telegram-bot-token
pass insert openclaw/slack-bot-token
```

Or store all service-level secrets as a single multi-line entry (one `KEY=value`
per line) — useful for populating the system service's `secrets.env`:

```bash
pass insert -m openclaw/secrets
# Paste the KEY=value block, then Ctrl-D:
#   ANTHROPIC_API_KEY=sk-ant-...
#   OPENCLAW_GATEWAY_TOKEN=<token>
#   channels__telegram__botToken=123456:ABCdef...
#   channels__slack__botToken=xoxb-...
```

### Using pass with `guix shell`

Inject secrets at invocation time via `$(pass show ...)`.  Shell history records
the `pass show` expression, not the secret value:

```bash
ANTHROPIC_API_KEY=$(pass show openclaw/anthropic-key) \
OPENCLAW_GATEWAY_TOKEN=$(pass show openclaw/gateway-token) \
guix shell -L . -C --pure --network \
  --preserve='^(ANTHROPIC_API_KEY|OPENCLAW_GATEWAY_TOKEN)$' \
  --share="$HOME/.openclaw-dev=/var/lib/openclaw" \
  --expose=/etc/ssl/certs \
  openclaw \
  -- env \
     OPENCLAW_STATE_DIR=/var/lib/openclaw \
     OPENCLAW_CONFIG_PATH=/var/lib/openclaw/openclaw.json \
     OPENCLAW_GATEWAY_PORT=18789 \
     OPENCLAW_LOG_LEVEL=info \
     OPENCLAW_NO_RESPAWN=1 \
     openclaw gateway
```

### Using pass with the system/home service

The system and home services read secrets from a plain-text `KEY=value` file at
startup.  Use pass as the source of truth and write the file out once (or after
rotating a key):

```bash
# System service
sudo mkdir -p /etc/openclaw
pass show openclaw/secrets | sudo tee /etc/openclaw/secrets.env > /dev/null
sudo chmod 640 /etc/openclaw/secrets.env
sudo chown root:openclaw /etc/openclaw/secrets.env
sudo herd restart openclaw

# Home service
mkdir -p ~/.openclaw
pass show openclaw/secrets > ~/.openclaw/secrets.env
chmod 600 ~/.openclaw/secrets.env
herd restart openclaw
```

The GPG-encrypted copy in pass remains the canonical record.  The on-disk
`secrets.env` is a deploy-time artefact — regenerate it from pass whenever you
rotate keys.

### What the `--pure` flag buys you

Without `--pure`, `guix shell -C` inherits the entire host environment,
including any variables already set in your shell session.  With `--pure`,
nothing enters the container unless you explicitly `--preserve` it.  This means
no accidental leakage of `HISTFILE`, `DBUS_SESSION_BUS_ADDRESS`, credentials
from other tools, etc.

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
a file readable only by root and the `openclaw` group, and point
`environment-file` at it.  The recommended workflow uses [GNU Pass](#secrets-management)
as the encrypted source of truth:

```bash
sudo mkdir -p /etc/openclaw
pass show openclaw/secrets | sudo tee /etc/openclaw/secrets.env > /dev/null
sudo chmod 640 /etc/openclaw/secrets.env
sudo chown root:openclaw /etc/openclaw/secrets.env
```

The file format is one `KEY=value` per line; blank lines and `#` comments are
ignored:

```bash
# /etc/openclaw/secrets.env  (chmod 640, root:openclaw)

ANTHROPIC_API_KEY=sk-ant-...
OPENCLAW_GATEWAY_TOKEN=<long-random-string>

# Channel credentials
channels__telegram__botToken=123456:ABCdef...
channels__slack__botToken=xoxb-...
channels__discord__token=MTA...
```

Regenerate the file from pass whenever you rotate a key, then restart the
service:

```bash
pass show openclaw/secrets | sudo tee /etc/openclaw/secrets.env > /dev/null
sudo herd restart openclaw
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
