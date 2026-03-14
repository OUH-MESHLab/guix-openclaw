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
    (version "2026.3.13")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://registry.npmjs.org/openclaw/-/openclaw-"
             version ".tgz"))
       (sha256
        (base32 "0sp941m4014k4lh8zaiyva61n57fw9jnh3h9spfdnaziqkwdj4b7"))))
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
                '("@grammyjs/types"
                  "@lit-labs/signals"
                  "@lit/context"
                  "@types/express"
                  "@types/markdown-it"
                  "@types/node"
                  "@types/qrcode-terminal"
                  "@types/ws"
                  "@typescript/native-preview"
                  "@vitest/coverage-v8"
                  "jscpd"
                  "jsdom"
                  "lit"
                  "oxfmt"
                  "oxlint"
                  "oxlint-tsgolint"
                  "signal-utils"
                  "tsdown"
                  "tsx"
                  "typescript"
                  "vitest"
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
     (list node-zod-4.3.6
           node-yaml-2.8.2
           node-ws-8.19.0
           node-undici-7.24.2
           node-tslog-4.10.2
           node-tar-7.5.11
           node-sqlite-vec-0.1.7-alpha.2
           node-sharp-0.34.5
           node-qrcode-terminal-0.12.0
           node-playwright-core-1.58.2
           node-pdfjs-dist-5.5.207
           node-osc-progress-0.3.0
           node-opusscript-0.1.1
           node-node-edge-tts-1.2.10
           node-markdown-it-14.1.1
           node-long-5.3.2
           node-linkedom-0.18.12
           node-jszip-3.10.1
           node-json5-2.2.3
           node-jiti-2.6.1
           node-ipaddr-js-2.3.0
           node-https-proxy-agent-8.0.0
           node-hono-4.12.7
           node-grammy-1.41.1
           node-file-type-21.3.2
           node-express-5.2.1
           node-dotenv-17.3.1
           node-discord-api-types-0.38.42
           node-croner-10.0.1
           node-commander-14.0.3
           node-cli-highlight-2.1.11
           node-chokidar-5.0.0
           node-chalk-5.6.2
           node-ajv-8.18.0
           node-whiskeysockets-baileys-7.0.0-rc.9
           node-slack-web-api-7.15.0
           node-slack-bolt-4.6.0
           node-sinclair-typebox-0.34.48
           node-mozilla-readability-0.6.0
           node-modelcontextprotocol-sdk-1.27.1
           node-mariozechner-pi-tui-0.58.0
           node-mariozechner-pi-coding-agent-0.58.0
           node-mariozechner-pi-ai-0.58.0
           node-mariozechner-pi-agent-core-0.58.0
           node-lydell-node-pty-1.2.0-beta.3
           node-line-bot-sdk-10.6.0
           node-larksuiteoapi-node-sdk-1.59.0
           node-homebridge-ciao-1.3.5
           node-grammyjs-transformer-throttler-1.2.1
           node-grammyjs-runner-2.0.3
           node-discordjs-voice-0.19.1
           node-clack-prompts-1.1.0
           node-buape-carbon-0.0.0-beta-20260216184201
           node-aws-sdk-client-bedrock-3.1009.0
           node-agentclientprotocol-sdk-0.16.1))
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
