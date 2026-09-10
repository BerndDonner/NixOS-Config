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


;; ---------------------------------------------------------------------------
;; Current document
;; ---------------------------------------------------------------------------

(define (current-path)
  (let* ([view (editor-focus)]
         [doc-id (editor->doc-id view)])
    (editor-document->path doc-id)))


;; ---------------------------------------------------------------------------
;; In-memory database
;;
;; Format:
;;
;;   (("/absolute/path/a" . 1234)
;;    ("/absolute/path/b" . 567))
;; ---------------------------------------------------------------------------

(define (saved-position path)
  (let ([entry (assoc path *cursor-history*)])
    (if entry
        (cdr entry)
        #f)))

(define (remove-path path entries)
  (filter
    (lambda (entry)
      (not (equal? (car entry) path)))
    entries))

(define (remember-position! path position)
  (let ([old-position (saved-position path)])
    (unless (equal? old-position position)
      (set! *cursor-history*
            (cons
              (cons path position)
              (remove-path path *cursor-history*)))

      (set! *cursor-history-dirty* #t)
      (schedule-save!))))


;; ---------------------------------------------------------------------------
;; Persistence
;; ---------------------------------------------------------------------------

(define (load-state!)
  (when (path-exists? *cursor-history-state-file*)
    (let ([state
           (call-with-input-file
             *cursor-history-state-file*
             (lambda (input)
               (~> input
                   read-port-to-string
                   read!)))])
      (when (list? state)
        (set! *cursor-history* state)))))

(define (flush-state!)
  (when *cursor-history-dirty*

    (unless (path-exists? *cursor-history-state-dir*)
      (create-directory! *cursor-history-state-dir*))

    (call-with-port
      (open-output-file
        *cursor-history-state-file*
        #:exists 'truncate)

      (lambda (output)
        (write-line! output (to-string *cursor-history*))))

    (set! *cursor-history-dirty* #f)))

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
;; Restore
;; ---------------------------------------------------------------------------

(define (restore-current-position!)
  (let* ([view (editor-focus)]
         [doc-id (editor->doc-id view)]
         [path (editor-document->path doc-id)])

    (when (string? path)
      (let ([position (saved-position path)])

        (when position
          ;; Clamp stored position if the file became shorter.
          (let* ([rope (editor->text doc-id)]
                 [length (text.rope-len-chars rope)]
                 [max-position (max 0 (- length 1))]
                 [position (min position max-position)])

            (set! *cursor-history-restoring* #t)

            (helix.static.set-current-selection-object!
              (helix.static.range->selection
                (helix.static.range position position)))

            (set! *cursor-history-restoring* #f)))))))


;; ---------------------------------------------------------------------------
;; Synchronisation
;; ---------------------------------------------------------------------------

(define (sync-current-position!)
  (unless *cursor-history-restoring*
    (let ([path (current-path)])

      (when (string? path)

        ;; We switched to another file.
        (if (not (equal? path *cursor-history-active-path*))
            (begin
              (set! *cursor-history-active-path* path)
              (restore-current-position!))

            ;; Still the same file: remember its current cursor.
            (remember-position! path (cursor-position)))))))


;; ---------------------------------------------------------------------------
;; Installation
;; ---------------------------------------------------------------------------

(define (cursor-history-install! state-dir state-file)
  (set! *cursor-history-state-dir* state-dir)
  (set! *cursor-history-state-file* state-file)

  (load-state!)

  ;; Normal-mode movement and other commands.
  (register-hook
    'post-command
    (lambda (_)
      (sync-current-position!)))

  ;; Cursor also moves while typing.
  (register-hook
    'post-insert-char
    (lambda (_)
      (sync-current-position!)))

  ;; Persist before changing away from a document.
  (register-hook
    'document-focus-lost
    (lambda (_)
      (flush-state!)

      ;; The new document becomes current after the focus change.
      (enqueue-thread-local-callback
        sync-current-position!)))

  ;; Known safe point for persistence.
  (register-hook
    'document-saved
    (lambda (_)
      (sync-current-position!)
      (flush-state!)))

  ;; Initial file passed as `hx foo`.
  (enqueue-thread-local-callback-with-delay
    20
    sync-current-position!))
