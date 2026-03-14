;;; guix-openclaw --- Guix channel for OpenClaw AI gateway
;;; Copyright © 2026 Rafael Palomar <rafaelpalomar@fastmail.com>
;;;
;;; This file is part of guix-openclaw.
;;;
;;; guix-openclaw is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or
;;; (at your option) any later version.

;;; Commentary:
;;;
;;; This file contains Node.js package definitions for openclaw's
;;; transitive runtime dependencies.  It was generated with:
;;;
;;;   echo '(use-modules (guix import npm-binary) (ice-9 pretty-print))
;;;         (for-each (lambda (pkg) (pretty-print pkg) (newline))
;;;                   (npm-binary-recursive-import "openclaw"))' | \
;;;     GUILE_LOAD_PATH=/path/to/guix-src guix repl
;;;
;;; Packages already available in gnu/packages/node-xyz.scm are omitted.
;;; Native-addon packages (sharp, @lydell/node-pty, sqlite-vec, opusscript)
;;; are not included; openclaw degrades gracefully without them.

(define-module (guix-openclaw packages node-openclaw-deps)
  #:use-module (gnu packages node)
  #:use-module (gnu packages node-xyz)
  #:use-module (guix build-system node)
  #:use-module (guix download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

;; Populated by the recursive importer output — see openclaw.scm TODO.
