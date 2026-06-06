# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A **Guix package channel** that provides declarative, reproducible package definitions for [OpenClaw](https://github.com/openclaw/openclaw) — a self-hosted multi-channel AI gateway that routes LLM conversations through messaging platforms (Telegram, WhatsApp, Slack, Discord, Signal, Matrix, IRC, etc.).

## Common Commands

```bash
# Build the main package
guix build -L . openclaw

# Run in a containerized shell
guix shell -L . -C openclaw -- openclaw --version

# Build a specific dependency from the generated file
guix build -L . node-sharp
```

## Architecture

```
.guix-channel                          # Identifies this as a Guix channel
guix-openclaw/packages/
  openclaw.scm                         # Main OpenClaw package (node-build-system)
  node-openclaw-deps.scm               # 810 generated npm dependency packages
```

**`openclaw.scm`** defines the top-level package using `node-build-system`. It removes dev-dependencies at patch time and disables the build phase (npm packages don't need compilation). All `#:tests? #f`.

**`node-openclaw-deps.scm`** is a **generated file** — do not edit by hand. It was produced by a custom recursive npm-binary importer (`guix/import/npm-binary.scm`) that gracefully skips unsupported version specifiers (`git+`, `file:`, `http:`, `npm:` aliases). To regenerate it, re-run that importer against OpenClaw's `package.json`.

## Key Patterns

- Build failures in the dep file are fixed by adding `#:phases` to specific packages — either deleting problematic npm scripts (babel builds, deno2node, etc.) or filtering to the right platform (e.g., `sqlite-vec` is `linux-x64` only).
  - Native addon packages (`sharp`, `@lydell/node-pty`, `sqlite-vec`, `opusscript`) may require additional `native-inputs` beyond what was auto-generated.
- Optional peer deps (`node-llama-cpp`, `@napi-rs/canvas`) are intentionally omitted — OpenClaw handles them gracefully when absent.
