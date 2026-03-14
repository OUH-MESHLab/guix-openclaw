;;; guix-openclaw --- Guix channel for OpenClaw AI gateway
;;; Copyright © 2026 Rafael Palomar <rafaelpalomar@fastmail.com>
;;;
;;; This file is part of guix-openclaw.
;;;
;;; guix-openclaw is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or
;;; (at your option) any later version.

(define-module (guix-openclaw packages node-runtime)
  #:use-module (gnu packages node)
  #:use-module (guix download)
  #:use-module (guix packages)
  #:use-module ((guix licenses) #:prefix license:))

;;; Node.js 22.16.0 — the minimum required by openclaw's runtime guard.
;;; Inherits everything from node-lts (22.14.0) in the official Guix channel;
;;; only the version string and source hash change.
(define-public node-22.16.0
  (package
    (inherit node-lts)
    (version "22.16.0")
    (source
     (origin
       (inherit (package-source node-lts))
       (uri (string-append "https://nodejs.org/dist/v" version
                           "/node-v" version ".tar.gz"))
       (sha256
        (base32
         "1cnsxcjp7b6s38bif8cndi76x1plc3x43vxkcjs07hcwyw7jb3qh"))))))
