;;; guix-openclaw --- Guix channel for OpenClaw AI gateway
;;; Copyright © 2026 Rafael Palomar <rafaelpalomar@fastmail.com>
;;;
;;; This file is part of guix-openclaw.
;;;
;;; guix-openclaw is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or
;;; (at your option) any later version.

(define-module (guix-openclaw packages openclaw)
  #:use-module (guix-openclaw packages node-openclaw-deps)
  #:use-module (guix-openclaw packages node-runtime)
  #:use-module (gnu packages node)
  #:use-module (gnu packages node-xyz)
  #:use-module (guix build-system node)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define-public openclaw
  (package
    (name "openclaw")
    (version "2026.6.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://registry.npmjs.org/openclaw/-/openclaw-"
             version ".tgz"))
       (sha256
        (base32 "1fx4d5iqc9y7054m6rxv78iya45i5qm6jhmabdvlgh8hv0gw8gp4"))))
    (build-system node-build-system)
    (arguments
     (list
      #:node node-22.16.0
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'build)
          (add-after 'patch-dependencies 'delete-dev-dependencies
            (lambda _
              (modify-json
               (delete-dependencies
                '("lit"
                  "tsx"
                  "jscpd"
                  "jsdom"
                  "oxfmt"
                  "shiki"
                  "unrun"
                  "oxlint"
                  "tsdown"
                  "vitest"
                  "esbuild"
                  "@a2ui/lit"
                  "@types/ws"
                  "@mdx-js/mdx"
                  "@types/node"
                  "@lit/context"
                  "signal-utils"
                  "@shikijs/core"
                  "@types/express"
                  "@grammyjs/types"
                  "oxlint-tsgolint"
                  "@lit-labs/signals"
                  "@copilotkit/aimock"
                  "@types/cross-spawn"
                  "@types/markdown-it"
                  "@vitest/coverage-v8"
                  "@types/hosted-git-info"
                  "@types/proper-lockfile"
                  "@shikijs/engine-oniguruma"
                  "@shikijs/engine-javascript"
                  "@typescript/native-preview"
                  ;; Optional peer deps — openclaw degrades gracefully without them
                  "node-llama-cpp"
                  "@napi-rs/canvas")))))
          ;; node-edge-tts requires https-proxy-agent@7 (CJS) but openclaw
          ;; hoists v8 (ESM-only) to the top-level node_modules.  The install
          ;; phase re-runs npm which overwrites node_modules, so fix after it.
          (add-after 'avoid-node-gyp-rebuild 'fix-edge-tts-nested-deps
            (lambda* (#:key outputs #:allow-other-keys)
              (use-modules (guix build utils))
              (let* ((out (assoc-ref outputs "out"))
                     (nested (string-append
                               out
                               "/lib/node_modules/openclaw"
                               "/node_modules/node-edge-tts/node_modules"))
                     (hpa-v7 #$(file-append
                                node-https-proxy-agent-7.0.6
                                "/lib/node_modules/https-proxy-agent")))
                (mkdir-p nested)
                (symlink hpa-v7
                         (string-append nested "/https-proxy-agent"))))))))
    (inputs
     (list node-grammyjs-transformer-throttler-1.2.1
           node-modelcontextprotocol-sdk-1.29.0
           node-agentclientprotocol-sdk-0.22.1
           node-earendil-works-pi-tui-0.78.1
           node-mozilla-readability-0.6.0
           node-mistralai-mistralai-2.2.5
           node-openclaw-proxyline-0.3.3
           node-openclaw-fs-safe-0.3.0
           node-anthropic-ai-sdk-0.100.1
           node-tree-sitter-bash-0.25.1
           node-lydell-node-pty-1.2.0-beta.12
           node-homebridge-ciao-1.3.9
           node-grammyjs-runner-2.0.3
           node-web-tree-sitter-0.26.9
           node-proper-lockfile-4.1.2
           node-playwright-core-1.60.0
           node-hosted-git-info-10.1.1
           node-clack-prompts-1.4.0
           node-node-edge-tts-1.2.10
           node-google-genai-2.7.0
           node-quickjs-wasi-3.0.0
           node-partial-json-0.1.7
           node-highlight-js-11.11.1
           node-cross-spawn-7.0.6
           node-clack-core-1.3.1
           node-typescript-6.0.3
           node-rastermill-0.3.1
           node-minimatch-10.2.5
           node-file-type-22.0.1
           node-commander-14.0.3
           node-web-push-3.6.7
           node-linkedom-0.18.12
           node-chokidar-5.0.0
           node-typebox-1.1.39
           node-express-5.2.1
           node-clawpdf-0.3.0
           node-undici-8.3.0
           node-qrcode-1.5.4
           node-openai-6.39.1
           node-kysely-0.29.2
           node-ignore-7.0.5
           node-grammy-1.43.0
           node-dotenv-17.4.2
           node-croner-10.0.1
           node-tslog-4.10.2
           node-jszip-3.10.1
           node-json5-2.2.3
           node-chalk-5.6.2
           node-yaml-2.9.0
           node-jiti-2.7.0
           node-glob-13.0.6
           node-diff-9.0.0
           node-zod-4.4.3
           node-tar-7.5.15
           node-ws-8.21.0))
    (home-page "https://github.com/openclaw/openclaw")
    (synopsis "Multi-channel AI gateway with extensible messaging integrations")
    (description
     "OpenClaw is a self-hosted personal AI assistant that routes LLM
conversations through multiple messaging platforms including Telegram,
WhatsApp, Slack, Discord, Signal, Matrix, IRC, and others.  It acts as
a control plane connecting an AI model of choice to various messaging
channels.  Features include multi-agent support, skill plugins, and a
web-based control UI.")
    (license license:expat)))
