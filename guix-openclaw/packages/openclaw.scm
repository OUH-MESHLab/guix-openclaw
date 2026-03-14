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
  #:use-module (gnu packages node)
  #:use-module (gnu packages node-xyz)
  #:use-module (guix build-system node)
  #:use-module (guix download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

;; NOTE: This file is a placeholder pending generation of
;; node-openclaw-deps.scm from the recursive npm-binary importer.
;; Once node-openclaw-deps.scm is populated, declare all runtime
;; inputs here and remove this comment.

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
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'build)
          (add-after 'patch-dependencies 'delete-dev-dependencies
            (lambda _
              (modify-json
               (delete-dependencies
                '("@grammyjs/types" "@lit-labs/signals" "@lit/context"
                  "@types/express" "@types/markdown-it" "@types/node"
                  "@types/qrcode-terminal" "@types/ws"
                  "@typescript/native-preview" "@vitest/coverage-v8"
                  "jscpd" "jsdom" "lit" "oxfmt" "oxlint"
                  "oxlint-tsgolint" "signal-utils" "tsdown" "tsx"
                  "typescript" "vitest"))))))))
    ;; TODO: replace with the generated node-openclaw-deps packages
    ;; once node-openclaw-deps.scm is populated.
    (inputs (list node))
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
