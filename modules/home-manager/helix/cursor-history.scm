(require "helix/editor.scm")
(require "helix/misc.scm")
(require (prefix-in helix.static. "helix/static.scm"))
(require-builtin helix/core/text as text.)

(#%require-dylib "libcursor_history_lock"
  (only-in
    cursor-history-lock-try-acquire
    cursor-history-lock-release))

(provide cursor-history-install! cursor-history-prune)

;; ---------------------------------------------------------------------------
;; Runtime state
;; ---------------------------------------------------------------------------

;; Entries are stored as:
;;
;;   (("/absolute/path/a" 42 17)
;;    ("/absolute/path/b" 3 5))
;;
;; Line and column are zero-based character coordinates.
(define *cursor-history* '())

(define *cursor-history-state-dir* #f)
(define *cursor-history-state-file* #f)
(define *cursor-history-lock-file* #f)
(define *cursor-history-temp-file* #f)

;; Path of the currently active document/view. This lets us distinguish
;; opening/switching to a document from ordinary cursor movement.
(define *cursor-history-active-path* #f)

;; Prevent selection hooks triggered by restore-position! from immediately
;; writing the restored position back as a user movement.
(define *cursor-history-restoring* #f)

;; Only paths changed by this Helix process are merged into the latest state
;; read from disk. This avoids lost updates when multiple Helix processes are
;; open at the same time.
(define *cursor-history-dirty-paths* '())
(define *cursor-history-dirty* #f)

;; Generation counter used by the 300 ms save debounce.
(define *cursor-history-save-generation* 0)


;; ---------------------------------------------------------------------------
;; In-memory state
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


(define (mark-path-dirty! path)
  (unless (member path *cursor-history-dirty-paths*)
    (set! *cursor-history-dirty-paths*
          (cons path *cursor-history-dirty-paths*))))


(define (remember-location! path location)
  (unless (equal? (saved-location path) location)
    (set! *cursor-history*
          (cons
            (cons path location)
            (remove-path path *cursor-history*)))

    (mark-path-dirty! path)
    (set! *cursor-history-dirty* #t)
    (schedule-save!)))


;; Merge only paths changed by this process into a freshly read disk state.
;; A dirty path missing from *cursor-history* represents a deletion; this is
;; useful for operations such as pruning stale entries.
(define (merge-dirty-paths disk-state)
  (foldl
    (lambda (path state)
      (let ([entry (assoc path *cursor-history*)])
        (if entry
            (cons entry (remove-path path state))
            (remove-path path state))))
    disk-state
    *cursor-history-dirty-paths*))


;; ---------------------------------------------------------------------------
;; Persistence
;; ---------------------------------------------------------------------------

(define (read-state-file)
  (if (path-exists? *cursor-history-state-file*)
      (let ([state
             (call-with-input-file
               *cursor-history-state-file*
               (lambda (input)
                 (read input)))])
        (if (list? state)
            state
            '()))
      '()))


(define (load-state!)
  (set! *cursor-history* (read-state-file)))


;; The native module keeps a stable lock file open and uses an OS-level file
;; lock. The file itself may remain on disk permanently; lock ownership is tied
;; to the open file descriptor, so the kernel releases it automatically if a
;; Helix process exits or is killed.
(define (try-acquire-lock!)
  (cursor-history-lock-try-acquire *cursor-history-lock-file*))


(define (release-lock!)
  (cursor-history-lock-release *cursor-history-lock-file*))


(define (write-state-atomically! state)
  ;; Write the complete new state first, then atomically replace the state
  ;; file. Both files live in the same directory/filesystem.
  (call-with-port
    (open-output-file
      *cursor-history-temp-file*
      #:exists 'truncate)
    (lambda (output)
      (write state output)
      (newline output)))

  (rename-file-or-directory!
    *cursor-history-temp-file*
    *cursor-history-state-file*))


(define (flush-state!)
  (when *cursor-history-dirty*
    (unless (path-exists? *cursor-history-state-dir*)
      (create-directory! *cursor-history-state-dir*))

    (if (try-acquire-lock!)
        (dynamic-wind
          ;; The lock was acquired before entering dynamic-wind.
          (lambda () #t)

          (lambda ()
            ;; Re-read the shared state only after acquiring the lock, then
            ;; merge this process's changes into that newest version.
            (let* ([disk-state (read-state-file)]
                   [merged-state (merge-dirty-paths disk-state)])
              (write-state-atomically! merged-state)

              ;; Our in-memory state now matches the state we wrote.
              (set! *cursor-history* merged-state)
              (set! *cursor-history-dirty-paths* '())
              (set! *cursor-history-dirty* #f)))

          ;; Also runs if the body raises a Scheme exception.
          (lambda ()
            (release-lock!)))

        ;; Another Helix process currently owns the kernel lock. Keep the
        ;; local changes dirty and retry shortly.
        (enqueue-thread-local-callback-with-delay
          50
          flush-state!))))


;; Cursor movement can generate many updates. Persist 300 ms after the most
;; recent change instead of writing once per movement.
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

         ;; Clamp locations if the file changed outside this Helix process.
         [line (min (car location) max-line)]
         [line-start (text.rope-line->char rope line)]
         [line-rope (text.rope->line rope line)]
         [line-length (text.rope-len-chars line-rope)]

         ;; Non-final lines include the newline character in their rope slice.
         [max-column
           (if (= line max-line)
               line-length
               (max 0 (- line-length 1)))]
         [column (min (cadr location) max-column)])

    (+ line-start column)))


;; ---------------------------------------------------------------------------
;; Restore and tracking
;; ---------------------------------------------------------------------------

(define (restore-position! rope path)
  (let ([location (saved-location path)])
    (when (location? location)
      (let ([position (location->position rope location)])
        (dynamic-wind
          (lambda ()
            (set! *cursor-history-restoring* #t))

          (lambda ()
            (helix.static.set-current-selection-object!
              (helix.static.range->selection
                (helix.static.range position position)))
            (helix.static.align_view_center))

          (lambda ()
            (set! *cursor-history-restoring* #f)))))))


(define (sync-current-position!)
  (unless *cursor-history-restoring*
    (let* ([view (editor-focus)]
           [doc-id (editor->doc-id view)]
           [path (editor-document->path doc-id)]
           [rope (editor->text doc-id)]
           [position (cursor-position)])

      (when (string? path)
        (if (not (equal? path *cursor-history-active-path*))
            (begin
              (set! *cursor-history-active-path* path)

              ;; When Helix reports position 0 for a newly active document,
              ;; restore the persisted location. A non-zero position wins,
              ;; which preserves explicit CLI positions such as `hx file:4:1`
              ;; and per-view cursor positions already maintained by Helix.
              (if (= position 0)
                  (restore-position! rope path)
                  (remember-location!
                    path
                    (position->location rope position))))

            ;; Same active document: ordinary cursor movement.
            (remember-location!
              path
              (position->location rope position)))))))


;; ---------------------------------------------------------------------------
;; Maintenance commands
;; ---------------------------------------------------------------------------

;;@doc
;; Remove cursor-history entries whose files no longer exist.
(define (cursor-history-prune)
  (let ([stale-paths
         (map car
           (filter
             (lambda (entry)
               (not (path-exists? (car entry))))
             *cursor-history*))])

    (for-each
      (lambda (path)
        (set! *cursor-history*
              (remove-path path *cursor-history*))
        (mark-path-dirty! path))
      stale-paths)

    (unless (null? stale-paths)
      (set! *cursor-history-dirty* #t)
      (flush-state!))

    (let ([count (length stale-paths)])
      (set-status!
        (if (= count 0)
            "Cursor history: no stale entries"
            (string-append
              "Cursor history: removed "
              (number->string count)
              (if (= count 1)
                  " stale entry"
                  " stale entries")))))))


;; ---------------------------------------------------------------------------
;; Installation
;; ---------------------------------------------------------------------------

(define (cursor-history-install! state-dir state-file)
  (set! *cursor-history-state-dir* state-dir)
  (set! *cursor-history-state-file* state-file)

  ;; Stable lock target for the native OS-level lock. Do not delete this file.
  (set! *cursor-history-lock-file*
        (string-append state-file ".lock"))

  ;; Same-directory temporary file used for atomic replacement.
  (set! *cursor-history-temp-file*
        (string-append state-file ".tmp"))

  (load-state!)

  ;; Covers normal cursor movement, including insert-mode typing.
  (register-hook
    'selection-did-change
    (lambda (_)
      (sync-current-position!)))

  ;; On a view/document switch, the hook observes the newly focused view.
  ;; Synchronize it immediately and persist pending changes.
  (register-hook
    'document-focus-lost
    (lambda (_)
      (sync-current-position!)
      (flush-state!)))

  ;; Saving is another useful persistence point in addition to the debounce.
  (register-hook
    'document-saved
    (lambda (_)
      (sync-current-position!)
      (flush-state!))))
