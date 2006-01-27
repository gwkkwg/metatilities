(in-package metatilities)

;;; ----------------------------------------------------------------------------
;;;
;;;   EXPORTS
;;;

(export 
 '(form-symbol-in-package
   form-symbol
   form-keyword
   form-uninterned-symbol
   
   current-load-file
   with-unique-names
   
   ensure-list 
   newsym
   export-exported-symbols

   length-at-most-p
   length-at-least-p
   length-1-list-p
   
   nearly-zero-p
   nearly-equal-p

   +whitespace-characters+
   whitespacep))


;;; ----------------------------------------------------------------------------
;;;
;;;   MACROS
;;;

(eval-when (:compile-toplevel :load-toplevel :execute)
  
  ;;; NOTE: can't use WITH-UNIQUE-NAMES here
  ;;; XXX This is a lousy name.  Don't export.
  (defmacro with-standard-printing (&body forms &aux (package (gensym "PACKAGE")))
    "Similar to WITH-STANDARD-IO-SYNTAX, but doesn't change packages."
    `(let ((,package *package*))
       (with-standard-io-syntax
         (let ((*package* ,package))
           ,@forms))))
  
  ) ; eval-when


;;; ----------------------------------------------------------------------------
;;;
;;;   PREDICATES
;;;

#-(or DIGITOOL OPENMCL)
(defun neq (left right)
  (not (eq left right)))

#-(or DIGITOOL OPENMCL)
(declaim (inline neq))

#-(or DIGITOOL OPENMCL)
(define-compiler-macro neq (left right)
  `(not (eq ,left ,right)))

;;; ----------------------------------------------------------------------------
;;;
;;;   FORMING SYMBOLS
;;;

(eval-when (:compile-toplevel :load-toplevel :execute)
  
  (defun form-symbol-in-package (package &rest names)
    (with-standard-printing
      (intern (format nil "~{~a~}" names)
              package)))
      
  (defun form-symbol (&rest names)
    (with-standard-printing
      (apply #'form-symbol-in-package *package* names)))
  
  (defun form-keyword (&rest names)
    (with-standard-printing
      (apply #'form-symbol-in-package (find-package :keyword)
             names)))
  
  (defun form-uninterned-symbol (&rest names)
    (with-standard-printing
      (make-symbol (format nil "~{~a~}" names))))
  
  ) ; eval-when

;;; ---------------------------------------------------------------------------

(defun current-load-file ()
  "Returns (if possible) the value of the file currently being loaded or from which
code is currently being evaluated."
  
  #+allegro excl:*source-pathname*
  #+Digitool (if *load-pathname* 
               *load-pathname*
               ;; This makes it work in a fred buffer...
               ccl:*loading-file-source-file*)
  #-(or lucid allegro Genera Explorer MCL)
  *load-pathname*)

;;; ---------------------------------------------------------------------------

(defmacro with-unique-names ((&rest vars) &body body)
  "Binds the symbols in VARS to gensyms.  cf with-gensyms."
  (assert (every #'symbolp vars) () "Can't rebind an expression.")
  `(let ,(mapcar #'(lambda (x) `(,x (gensym* ',x))) vars)
     ,@body))

;;; ---------------------------------------------------------------------------

(defun ensure-list (x)
  (if (listp x) x (list x)))

;;; ---------------------------------------------------------------------------
;;; newsym
;;;
;;; Sometimes it's nice to have your gensyms mean something when
;;; you're reading the macroexpansion of some form.  The problem
;;; is that if you give a prefix to GENSYM it remains the prefix
;;; until you change it.  
;;; ---------------------------------------------------------------------------

(eval-when
  #+CLTL2 (:compile-toplevel :load-toplevel :execute) #-CLTL2 (compile load eval)
  ;; the eval-when is because the newsym function is used in expanding
  ;; `with-variables' and other macros below.
  
  (defvar *newsym-counter* 0
    "Counter used by NEWSYM for generating print names.")
  
  (defun newsym (&optional (prefix "X"))
    "Create a new uninterned symbol whose print name begins with `prefix', which
may be a string or a symbol.  This differs from `gensym' in that the prefix is
not sticky."
    (unless (stringp prefix)
      (setf prefix (string prefix)))
    (make-symbol (format nil "~a~4,'0d" prefix (incf *newsym-counter*)))))

;;; ---------------------------------------------------------------------------

(defun export-exported-symbols (from-package to-package)
  "Make the exported symbols in from-package be also exported from to-package."
  (use-package from-package to-package)
  (do-external-symbols (sym (find-package from-package))
    (export sym to-package)))

;;; ---------------------------------------------------------------------------

(defgeneric length-at-least-p (thing length)
  (:documentation "Returns true if thing has no fewer than length elements in it."))

;;; ---------------------------------------------------------------------------

(defmethod length-at-least-p ((thing sequence) length)
  (>= (length thing) length))

;;; ---------------------------------------------------------------------------

(defmethod length-at-least-p ((thing cons) length)
  (let ((temp thing))
    (loop repeat (1- length)
          while temp do
          (setf temp (rest temp)))
    (not (null temp))))

;;; ---------------------------------------------------------------------------

(defgeneric length-at-most-p (thing length)
  (:documentation "Returns true if thing has no more than length elements in it."))

;;; ---------------------------------------------------------------------------

(defmethod length-at-most-p ((thing sequence) length)
  (<= (length thing) length))

;;; ---------------------------------------------------------------------------

(defmethod length-at-most-p ((thing cons) length)
  ;;?? cf. length-at-least-p, this seems similar
  (let ((temp thing))
    (loop repeat length
          while temp do
          (setf temp (rest temp)))
    (null temp)))

;;; ---------------------------------------------------------------------------

;; Much better than doing (= (length x) 1).
(declaim (inline length-1-list-p))
(defun length-1-list-p (x) 
  "Is x a list of length 1?"
  (and (consp x) (null (cdr x))))

;;; ---------------------------------------------------------------------------

(defun nearly-zero-p (x &optional (threshold 0.0001))
  (declare (optimize (speed 3) (space 3) (debug 0) (safety 0))
           (dynamic-extent x threshold))
  ;; ABS conses
  (if (< 0.0 x)
    (> threshold x)
    (> x threshold)))

#+Test
(timeit (:report t)
        (loop repeat 100000 do
              (nearly-zero-p 10.1)
              (nearly-zero-p 0.00001)
              (nearly-zero-p -0.00001)))

;;; ---------------------------------------------------------------------------

(defun nearly-equal-p (x y threshold)
  (declare (optimize (speed 3) (space 3) (debug 0) (safety 0))
           (dynamic-extent x y threshold)
           (type double-float x y threshold))
  (let ((temp 0.0d0))
    (declare (type double-float temp)
             (dynamic-extent temp))
    (cond ((> x y)
           (setf temp (the double-float (- x y)))
           (< temp threshold))
          (t
           (setf temp (the double-float (- y x)))
           (< temp threshold)))))

#+Test
(timeit (:report t)
        (loop repeat 100000 do
              (nearly-equal-p 10.1 10.2 0.0001)
              (nearly-equal-p 10.2342345 10.234234 0.0001)))

;;; ---------------------------------------------------------------------------
;;; whitespace-p
;;; ---------------------------------------------------------------------------

(defparameter +whitespace-characters+
  (list #\Space #\Newline #\Tab #\Page #\Null #\Linefeed))

;;; ---------------------------------------------------------------------------

(defun whitespacep (char)
  (find char +whitespace-characters+ :test #'char=))







