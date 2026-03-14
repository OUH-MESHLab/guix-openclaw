;;; guix-openclaw --- Guix channel for OpenClaw AI gateway
;;; Copyright © 2026 Rafael Palomar <rafaelpalomar@fastmail.com>
;;;
;;; This file is part of guix-openclaw.
;;;
;;; guix-openclaw is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; guix-openclaw is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with guix-openclaw.  If not, see <http://www.gnu.org/licenses/>.

;;;
;;; Usage — system service (server/NAS deployment):
;;;
;;;   (service openclaw-service-type
;;;     (openclaw-configuration
;;;       (port 18789)
;;;       (bind-address "127.0.0.1")   ; expose via nginx or tailscale serve
;;;       (auth-mode 'token)
;;;       (environment-file "/etc/openclaw/secrets.env")
;;;       (log-level "info")))
;;;
;;;   /etc/openclaw/secrets.env contains lines such as:
;;;     ANTHROPIC_API_KEY=sk-ant-...
;;;     OPENCLAW_GATEWAY_TOKEN=my-secret-token
;;;     channels__telegram__botToken=123456:ABC...
;;;
;;; Usage — home service (personal workstation):
;;;
;;;   (service home-openclaw-service-type
;;;     (home-openclaw-configuration
;;;       (port 18789)
;;;       (environment-file
;;;         (string-append (getenv "HOME") "/.openclaw/secrets.env"))))
;;;

(define-module (guix-openclaw services openclaw)
  #:use-module (guix-openclaw packages openclaw)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu packages admin)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system shadow)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix records)
  #:export (openclaw-configuration
            openclaw-configuration?
            openclaw-configuration-openclaw
            openclaw-configuration-user
            openclaw-configuration-group
            openclaw-configuration-state-directory
            openclaw-configuration-port
            openclaw-configuration-bind-address
            openclaw-configuration-auth-mode
            openclaw-configuration-environment-file
            openclaw-configuration-log-level
            openclaw-configuration-config-file
            openclaw-service-type

            home-openclaw-configuration
            home-openclaw-configuration?
            home-openclaw-configuration-openclaw
            home-openclaw-configuration-port
            home-openclaw-configuration-bind-address
            home-openclaw-configuration-auth-mode
            home-openclaw-configuration-environment-file
            home-openclaw-configuration-log-level
            home-openclaw-configuration-config-file
            home-openclaw-service-type))


;;;
;;; Configuration records
;;;

(define-record-type* <openclaw-configuration>
  openclaw-configuration make-openclaw-configuration
  openclaw-configuration?
  ;; The openclaw package to use.
  (openclaw         openclaw-configuration-openclaw
                    (default openclaw))
  ;; System user that owns the process and state directory.
  (user             openclaw-configuration-user
                    (default "openclaw"))
  ;; System group.
  (group            openclaw-configuration-group
                    (default "openclaw"))
  ;; Root of all persistent OpenClaw state (database, sessions, uploads).
  (state-directory  openclaw-configuration-state-directory
                    (default "/var/lib/openclaw"))
  ;; TCP port the gateway listens on.
  (port             openclaw-configuration-port
                    (default 18789))
  ;; Address to bind; "127.0.0.1" keeps the gateway off the public network.
  ;; Expose it via nginx, Caddy, or Tailscale's own service.
  (bind-address     openclaw-configuration-bind-address
                    (default "127.0.0.1"))
  ;; Authentication mode: 'token | 'password | 'none
  (auth-mode        openclaw-configuration-auth-mode
                    (default 'token))
  ;; Path to a KEY=value file read at runtime.  Keeps API keys, channel
  ;; tokens, and OPENCLAW_GATEWAY_TOKEN out of the Guix store.
  (environment-file openclaw-configuration-environment-file
                    (default #f))
  ;; Log verbosity: "trace" | "debug" | "info" | "warn" | "error"
  (log-level        openclaw-configuration-log-level
                    (default "info"))
  ;; file-like | #f.  When #f a minimal openclaw.json is generated that
  ;; suppresses the onboarding wizard and seeds gateway/logging settings.
  (config-file      openclaw-configuration-config-file
                    (default #f)))

(define-record-type* <home-openclaw-configuration>
  home-openclaw-configuration make-home-openclaw-configuration
  home-openclaw-configuration?
  ;; The openclaw package to use.
  (openclaw         home-openclaw-configuration-openclaw
                    (default openclaw))
  ;; TCP port the gateway listens on.
  (port             home-openclaw-configuration-port
                    (default 18789))
  ;; Address to bind.
  (bind-address     home-openclaw-configuration-bind-address
                    (default "127.0.0.1"))
  ;; Authentication mode: 'token | 'password | 'none
  (auth-mode        home-openclaw-configuration-auth-mode
                    (default 'token))
  ;; Path to a KEY=value file read at runtime.
  (environment-file home-openclaw-configuration-environment-file
                    (default #f))
  ;; Log verbosity.
  (log-level        home-openclaw-configuration-log-level
                    (default "info"))
  ;; file-like | #f.  When #f a minimal openclaw.json is generated.
  (config-file      home-openclaw-configuration-config-file
                    (default #f)))


;;;
;;; Generated config file
;;;
;;; Produces a minimal JSON5 that:
;;;   - prevents the onboarding wizard (gateway block present)
;;;   - explicitly sets tailscale.mode = "off" (separate concern)
;;;   - leaves channels, models, tools, identity to the user
;;;

(define (openclaw-generated-config port bind-address auth-mode log-level)
  "Return a file-like object for a minimal openclaw.json seeded from fields."
  (mixed-text-file "openclaw.json"
    "{\n"
    "  gateway: {\n"
    "    mode: \"local\",\n"
    "    port: " (number->string port) ",\n"
    "    bind: \"" bind-address "\",\n"
    "    auth: { mode: \"" (symbol->string auth-mode) "\" },\n"
    "    tailscale: { mode: \"off\" }\n"
    "  },\n"
    "  logging: { level: \"" log-level "\" }\n"
    "}\n"))


;;;
;;; System accounts
;;;

(define %openclaw-accounts
  (list (user-group
         (name "openclaw")
         (system? #t))
        (user-account
         (name "openclaw")
         (group "openclaw")
         (system? #t)
         (comment "OpenClaw AI gateway daemon")
         (home-directory "/var/lib/openclaw")
         (shell (file-append shadow "/sbin/nologin")))))


;;;
;;; Activation (system service only)
;;;
;;; Creates the state directory and seeds the config file exactly once.
;;; Subsequent reconfigures never overwrite openclaw.json so that
;;; `openclaw config set` changes survive.
;;;

(define (openclaw-activation config)
  (let* ((state-dir  (openclaw-configuration-state-directory config))
         (port       (openclaw-configuration-port config))
         (bind       (openclaw-configuration-bind-address config))
         (auth-mode  (openclaw-configuration-auth-mode config))
         (log-level  (openclaw-configuration-log-level config))
         (cfg-src    (or (openclaw-configuration-config-file config)
                         (openclaw-generated-config
                          port bind auth-mode log-level)))
         (cfg-dest   (string-append state-dir "/openclaw.json")))
    #~(begin
        (use-modules (guix build utils))
        (let* ((user    (getpwnam #$( openclaw-configuration-user config)))
               (uid     (passwd:uid user))
               (gid     (passwd:gid user)))
          ;; 1. Ensure state directory exists with correct ownership.
          (mkdir-p #$state-dir)
          (chown #$state-dir uid gid)
          (chmod #$state-dir #o750)
          ;; 2. Seed config only on first deployment; never overwrite.
          (unless (file-exists? #$cfg-dest)
            (copy-file #$cfg-src #$cfg-dest)
            (chown #$cfg-dest uid gid)
            (chmod #$cfg-dest #o640))))))


;;;
;;; Shepherd service helpers
;;;

(define (openclaw-environment-variables state-dir port log-level env-file)
  "Build the environment variable list for the shepherd start constructor.
Variables from ENV-FILE (if present and readable) are appended after the
base set so they can override defaults.  Only non-empty KEY=VALUE lines
that contain '=' are admitted; blank lines and comments are silently dropped."
  #~(let* ((base-env
            (list (string-append "OPENCLAW_STATE_DIR=" #$state-dir)
                  (string-append "OPENCLAW_CONFIG_PATH="
                                 #$state-dir "/openclaw.json")
                  (string-append "OPENCLAW_GATEWAY_PORT="
                                 (number->string #$port))
                  (string-append "OPENCLAW_LOG_LEVEL=" #$log-level)
                  "OPENCLAW_NO_RESPAWN=1"
                  "SSL_CERT_DIR=/etc/ssl/certs"
                  "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"))
           (file-env
            (if (and #$env-file (file-exists? #$env-file))
                (filter (lambda (s)
                          (and (not (string-null? s))
                               (not (string-prefix? "#" s))
                               (string-index s #\=)))
                        (string-split
                         (call-with-input-file #$env-file get-string-all)
                         #\newline))
                '())))
      (append base-env file-env)))


;;;
;;; System shepherd service
;;;

(define (openclaw-shepherd-service config)
  (let* ((pkg        (openclaw-configuration-openclaw config))
         (user       (openclaw-configuration-user config))
         (group      (openclaw-configuration-group config))
         (state-dir  (openclaw-configuration-state-directory config))
         (port       (openclaw-configuration-port config))
         (log-level  (openclaw-configuration-log-level config))
         (env-file   (openclaw-configuration-environment-file config))
         (env-vars   (openclaw-environment-variables
                      state-dir port log-level env-file)))
    (list
     (shepherd-service
      (provision '(openclaw))
      (documentation "Run the OpenClaw AI gateway.")
      (requirement '(user-processes networking))
      (modules '((ice-9 textual-ports)
                 (ice-9 string-fun)))
      (start #~(lambda _
                 ((make-forkexec-constructor
                   (list #$(file-append pkg "/bin/openclaw") "gateway")
                   #:user #$user
                   #:group #$group
                   #:log-file (string-append #$state-dir "/openclaw.log")
                   #:environment-variables #$env-vars))))
      (stop #~(make-kill-destructor))
      (respawn? #t)))))


;;;
;;; System service type
;;;

(define openclaw-service-type
  (service-type
   (name 'openclaw)
   (extensions
    (list (service-extension shepherd-root-service-type
                             openclaw-shepherd-service)
          (service-extension account-service-type
                             (const %openclaw-accounts))
          (service-extension activation-service-type
                             openclaw-activation)))
   (default-value (openclaw-configuration))
   (description
    "Run the OpenClaw multi-channel AI gateway as a Shepherd system service.
OpenClaw routes LLM conversations through messaging platforms such as
Telegram, WhatsApp, Slack, Discord, and others.  Channel credentials and
API keys belong in the @var{environment-file}, not in the service record.")))


;;;
;;; Home shepherd service
;;;

(define (home-openclaw-shepherd-service config)
  (let* ((pkg       (home-openclaw-configuration-openclaw config))
         (port      (home-openclaw-configuration-port config))
         (log-level (home-openclaw-configuration-log-level config))
         (env-file  (home-openclaw-configuration-environment-file config))
         ;; For home service the state dir is $HOME/.openclaw, resolved at
         ;; runtime via OPENCLAW_HOME; we pass a literal path here that
         ;; shepherd expands relative to the actual home directory.
         (state-dir "$HOME/.openclaw")
         (env-vars  (openclaw-environment-variables
                     state-dir port log-level env-file)))
    (list
     (shepherd-service
      (provision '(openclaw))
      (documentation "Run the OpenClaw AI gateway (home service).")
      (requirement '())
      (modules '((ice-9 textual-ports)
                 (ice-9 string-fun)))
      (start #~(lambda _
                 ((make-forkexec-constructor
                   (list #$(file-append pkg "/bin/openclaw") "gateway")
                   #:log-file (string-append
                               (getenv "HOME") "/.openclaw/openclaw.log")
                   #:environment-variables #$env-vars))))
      (stop #~(make-kill-destructor))
      (respawn? #t)))))


;;;
;;; Home service type
;;;

(define home-openclaw-service-type
  (service-type
   (name 'home-openclaw)
   (extensions
    (list (service-extension home-shepherd-service-type
                             home-openclaw-shepherd-service)
          (service-extension home-profile-service-type
                             (compose list home-openclaw-configuration-openclaw))))
   (default-value (home-openclaw-configuration))
   (description
    "Run the OpenClaw multi-channel AI gateway as a Guix Home Shepherd service.
State is kept in @file{~/.openclaw}.  Channel credentials and API keys
belong in the @var{environment-file}, not in the service record.")))
