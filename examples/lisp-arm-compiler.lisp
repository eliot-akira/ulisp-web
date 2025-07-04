; Lisp compiler to ARM Thumb Assembler - Version 2a - 23rd August 2024
; http://www.ulisp.com/show?4W2I

; Compile a lisp function

(defun compile (name)
  (if (eq (car (eval name)) 'lambda)
      (eval (comp (cons 'defun (cons name (cdr (eval name))))))
    (error "Not a Lisp function")))

; The main compile routine - returns compiled code for x, prefixed by type :integer or :boolean
; Leaves result in r0

(defun comp (x &optional env)
  (cond
   ((null x) (type-code :boolean '(($mov 'r0 0))))
   ((eq x t) (type-code :boolean '(($mov 'r0 1))))
   ((symbolp x) (comp-symbol x env))
   ((atom x) (type-code :integer (list (list '$mov ''r0 x))))
   (t (let ((fn (first x)) (args (rest x)))
        (case fn
          (defun (setq *label-num* 0)
                 (setq env (mapcar #'(lambda (x y) (cons x y)) (second args) *locals*))
                 (comp-defun (first args) (second args) (cddr args) env))
          (progn (comp-progn args env))
          (if    (comp-if (first args) (second args) (third args) env))
          (setq  (comp-setq args env))
          (t     (comp-funcall fn args env)))))))

; Utilities

; Like mapcon but not destructive

(defun mappend (fn lst)
  (apply #'append (mapcar fn lst)))

; The type is prefixed onto the list of assembler code instructions

(defun type-code (type code) (cons type code))

(defun code-type (type-code) (car type-code))

(defun code (type-code) (cdr type-code))

(defun checktype (fn type check)
  (unless (or (null type) (null check) (eq type check))
    (error "Argument to '~a' must be ~a not ~a" fn check type)))

; Allocate registers

(defvar *params* '(r0 r1 r2 r3))

(defvar *locals* '(r4 r5 r6 r7))

; Generate a label

(defvar *label-num* 0)

(defun gen-label ()
  (read-from-string (format nil "lab~d" (incf *label-num*))))

; Subfunctions

(defun comp-symbol (x env)
  (let ((reg (cdr (assoc x env))))
    (type-code nil (list (list '$mov ''r0 (list 'quote reg))))))

(defun comp-setq (args env)
  (let ((value (comp (second args) env))
        (reg (cdr (assoc (first args) env))))
    (type-code 
     (code-type value) 
     (append (code value) (list (list '$mov (list 'quote reg) ''r0))))))

(defun comp-defun (name args body env)
  (let ((used (subseq *locals* 0 (length args))))
    (append 
     (list 'defcode name args)
     (list name (list '$push (list 'quote (cons 'lr (reverse used)))))
     (apply #'append 
            (mapcar #'(lambda (x y) (list (list '$mov (list 'quote x) (list 'quote y))))
                    used *params*))
     (code (comp-progn body env))
     (list (list '$pop (list 'quote (append used (list 'pc))))))))

(defun comp-progn (exps env)
  (let* ((len (1- (length exps)))
         (nlast (subseq exps 0 len))
         (last1 (nth len exps))
         (start (mappend #'(lambda (x) (append (code (comp x env)))) nlast))
         (end (comp last1 env)))
    (type-code (code-type end) (append start (code end)))))

(defun comp-if (pred then else env)
  (let ((lab1 (gen-label))
        (lab2 (gen-label))
        (test (comp pred env)))
    (checktype 'if (car test) :boolean)
    (type-code :integer
               (append
                (code test) (list '($cmp 'r0 0) (list '$beq lab1))
                (code (comp then env)) (list (list '$b lab2) lab1)
                (code (comp else env)) (list lab2)))))

(defun comp-funcall (f args env)
  (let ((test (assoc f '((> . $bgt) (>= . $bge) (= . $beq) 
                         (<= . $ble) (< . $blt) (/= . $bne))))
        (logical (assoc f '((and . $and) (or . $orr))))
        (arith1 (assoc f '((1+ . $add) (1- . $sub))))
        (arith+- (assoc f '((+ . $add) (- . $sub))))
        (arith2 (assoc f '((* . $mul) (logand . $and) (logior . $orr) (logxor . $eor)))))
    (cond
     (test
      (let ((label (gen-label)))
        (type-code :boolean
                   (append
                    (comp-args f args 2 :integer env)
                    (list '($pop '(r1)) '($mov 'r2 1) '($cmp 'r1 'r0) 
                          (list (cdr test) label) '($mov 'r2 0) label '($mov 'r0 'r2))))))
     (logical 
      (type-code :boolean
                 (append
                  (comp-args f args 2 :boolean env)
                  (list '($pop '(r1)) (list (cdr logical) ''r0 ''r1)))))
     (arith1
      (type-code :integer 
                 (append
                  (comp-args f args 1 :integer env)
                  (list (list (cdr arith1) ''r0 1)))))
     (arith+-
      (type-code :integer 
                 (append
                  (comp-args f args 2 :integer env)
                  (list '($pop '(r1)) (list (cdr arith+-) ''r0 ''r1 ''r0)))))
     (arith2
      (type-code :integer 
                 (append
                  (comp-args f args 2 :integer env)
                  (list '($pop '(r1)) (list (cdr arith2) ''r0 ''r1)))))
     ((member f '(car cdr))
      (type-code :integer
                 (append
                  (comp-args f args 1 :integer env)
                  (if (eq f 'cdr) (list '($ldr 'r0 '(r0 4)))
                    (list '($ldr 'r0 '(r0 0)) '($ldr 'r0 '(r0 4)))))))
     (t ; function call
      (type-code :integer 
                 (append
                  (comp-args f args nil :integer env)
                  (when (> (length args) 1)
                    (append
                     (list (list '$mov (list 'quote (nth (1- (length args)) *params*)) ''r0))
                     (mappend
                      #'(lambda (x) (list (list '$pop (list 'quote (list x)))))
                      (reverse (subseq *params* 0 (1- (length args)))))))
                  (list (list '$bl f))))))))

(defun comp-args (fn args n type env)
  (unless (or (null n) (= (length args) n))
    (error "Incorrect number of arguments to '~a'" fn))
  (let ((n (length args)))
    (mappend #'(lambda (y)
                 (let ((c (comp y env)))
                   (decf n)
                   (checktype fn type (code-type c))
                   (if (zerop n) (code c) (append (code c) '(($push '(r0)))))))
             args)))