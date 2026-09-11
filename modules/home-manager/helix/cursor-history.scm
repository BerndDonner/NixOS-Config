(require "helix/editor.scm")
(require "helix/misc.scm")
(require (prefix-in helix.static. "helix/static.scm"))
(require-builtin helix/core/text as text.)

(provide cursor-history-install!)

;; ---------------------------------------------------------------------------
;; State
;; ---------------------------------------------------------------------------

(define *cursor-history* '())

(define *cursor-history-state-dir* #f)
(define *cursor-history-state-file* #f)

(define *cursor-history-active-path* #f)
(define *cursor-history-restoring* #f)

(define *cursor-history-dirty* #f)
(define *cursor-history-save-generation* 0)

(define *cursor-history-dirty-paths* '())

(define *cursor-history-lock-file* #f)
(define *cursor-history-temp-file* #f)


(define (mark-path-dirty! path)
  (unless (member path *cursor-history-dirty-paths*)
    (set! *cursor-history-dirty-paths*
          (cons path *cursor-history-dirty-paths*))))


(define (try-acquire-lock!)
  (call/cc
    (lambda (k)
      (call-with-exception-handler
        (lambda (_)
          (k #f))
        (lambda ()
          (call-with-port
            (open-output-file
              *cursor-history-lock-file*
              #:exists 'error)
            (lambda (_)
              #t))
          #t)))))


(define (release-lock!)
  (when (path-exists? *cursor-history-lock-file*)
    (delete-file! *cursor-history-lock-file*)))

;; ---------------------------------------------------------------------------
;; In-memory database
;;
;; Format:
;;
;;   (("/absolute/path/a" 42 17)
;;    ("/absolute/path/b" 3 5))
;;
;; Line and column are zero-based character coordinates.
;; ---------------------------------------------------------------------------

(define (saved-location path)
  (let ([entry (assoc path *cursor-history*)])
    (if entry
        (cdr entry)
        #f)))

(define (remove-path path entries)
  (filter
    (lambda (entry)
      (not (equal? (car entry) path)))
    entries))

(define (remember-location! path location)
  (let ([old-location (saved-location path)])
    (unless (equal? old-location location)
      (set! *cursor-history*
            (cons
              (cons path location)
              (remove-path path *cursor-history*)))

      (mark-path-dirty! path)
      (set! *cursor-history-dirty* #t)
      (schedule-save!))))


(define (merge-dirty-paths disk-state)
  (foldl
    (lambda (path state)
      (let ([entry (assoc path *cursor-history*)])
        (if entry
            (cons entry (remove-path path state))
            state)))
    disk-state
    *cursor-history-dirty-paths*))


;; ---------------------------------------------------------------------------
;; Persistence
;; ---------------------------------------------------------------------------

(define (load-state!)
  (when (path-exists? *cursor-history-state-file*)
    (let ([state
           (call-with-input-file
             *cursor-history-state-file*
             (lambda (input)
               (read input)))])
      (when (list? state)
        (set! *cursor-history* state)))))


(define (flush-state!)
  (when *cursor-history-dirty*

    (unless (path-exists? *cursor-history-state-dir*)
      (create-directory! *cursor-history-state-dir*))

    (if (try-acquire-lock!)

        (dynamic-wind

          ;; Lock is already acquired.
          (lambda ()
            #t)

          (lambda ()
            (let* ([disk-state
                    (if (path-exists? *cursor-history-state-file*)
                        (call-with-input-file
                          *cursor-history-state-file*
                          (lambda (input)
                            (read input)))
                        '())]

                   [merged-state
                    (merge-dirty-paths disk-state)])

              ;; Write a complete new file first.
              (call-with-port
                (open-output-file
                  *cursor-history-temp-file*
                  #:exists 'truncate)
                (lambda (output)
                  (write merged-state output)
                  (newline output)))

              ;; Atomic replacement on the same filesystem.
              (rename-file-or-directory!
                *cursor-history-temp-file*
                *cursor-history-state-file*)

              ;; Synchronize our in-memory view with what we just wrote.
              (set! *cursor-history* merged-state)
              (set! *cursor-history-dirty-paths* '())
              (set! *cursor-history-dirty* #f)))

          ;; Runs on normal return AND Scheme exceptions.
          (lambda ()
            (release-lock!)))

        ;; Another Helix process currently writes.
        ;; Keep everything dirty and simply retry shortly.
        (enqueue-thread-local-callback-with-delay
          50
          flush-state!))))


;; Don't write the cache file for every cursor movement.
;; Save 300 ms after the last change.
(define (schedule-save!)
  (set! *cursor-history-save-generation*
        (+ *cursor-history-save-generation* 1))

  (let ([generation *cursor-history-save-generation*])
    (enqueue-thread-local-callback-with-delay
      300
      (lambda ()
        (when (= generation *cursor-history-save-generation*)
          (flush-state!))))))


;; ---------------------------------------------------------------------------
;; Position conversion
;; ---------------------------------------------------------------------------

(define (position->location rope position)
  (let* ([line (text.rope-char->line rope position)]
         [line-start (text.rope-line->char rope line)]
         [column (- position line-start)])
    (list line column)))


(define (location? value)
  (and
    (list? value)
    (= (length value) 2)
    (integer? (car value))
    (integer? (cadr value))
    (>= (car value) 0)
    (>= (cadr value) 0)))


(define (location->position rope location)
  (let* ([line-count (text.rope-len-lines rope)]
         [max-line (max 0 (- line-count 1))]

         ;; Clamp if lines were removed.
         [line (min (car location) max-line)]

         [line-start (text.rope-line->char rope line)]
         [line-rope (text.rope->line rope line)]
         [line-length (text.rope-len-chars line-rope)]

         ;; Non-final lines include the newline.
         [max-column
           (if (= line max-line)
               line-length
               (max 0 (- line-length 1)))]

         ;; Clamp if the line became shorter.
         [column (min (cadr location) max-column)])

    (+ line-start column)))


;; ---------------------------------------------------------------------------
;; Restore
;; ---------------------------------------------------------------------------

(define (restore-position! rope path)
  (let ([location (saved-location path)])

    (when (location? location)
      (let ([position
             (location->position rope location)])

        (set! *cursor-history-restoring* #t)

        (helix.static.set-current-selection-object!
          (helix.static.range->selection
            (helix.static.range position position)))

        (helix.static.align_view_center)

        (set! *cursor-history-restoring* #f)))))


;; ---------------------------------------------------------------------------
;; Synchronisation
;; ---------------------------------------------------------------------------

(define (sync-current-position!)
  (unless *cursor-history-restoring*
    (let* ([view (editor-focus)]
           [doc-id (editor->doc-id view)]
           [path (editor-document->path doc-id)]
           [rope (editor->text doc-id)]
           [position (cursor-position)])

      (when (string? path)

        (if (not (equal? path *cursor-history-active-path*))

            ;; A different document/view became active.
            (begin
              (set! *cursor-history-active-path* path)

              ;; Position zero means Helix has not supplied a meaningful
              ;; position. Restore our persisted location if available.
              ;;
              ;; A non-zero position wins over the cache, e.g.
              ;; `hx file:4:1` or an existing Helix view.
              (if (= position 0)
                  (restore-position! rope path)
                  (remember-location!
                    path
                    (position->location rope position))))

            ;; Same document: normal cursor movement.
            (remember-location!
              path
              (position->location rope position)))))))


;; ---------------------------------------------------------------------------
;; Installation
;; ---------------------------------------------------------------------------

(define (cursor-history-install! state-dir state-file)
  (set! *cursor-history-state-dir* state-dir)
  (set! *cursor-history-state-file* state-file)

  (set! *cursor-history-lock-file*
        (string-append state-file ".lock"))

  (set! *cursor-history-temp-file*
        (string-append state-file ".tmp"))

  (load-state!)

  ;; Normal-mode movement and other commands.
  (register-hook
    'selection-did-change
    (lambda (_)
      (sync-current-position!)))

  ;; Persist before changing away from a document.
  (register-hook
    'document-focus-lost
    (lambda (_)
      (sync-current-position!)
      (flush-state!)))

  ;; Known safe point for persistence.
  (register-hook
    'document-saved
    (lambda (_)
      (sync-current-position!)
      (flush-state!))))
