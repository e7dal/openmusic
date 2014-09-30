;OpenMusic : trajectory editor
;
;Copyright (C) 1997-2010 by IRCAM-Centre Georges Pompidou, Paris, France.
; 
;This program is free software; you can redistribute it and/or
;modify it under the terms of the GNU General Public License
;as published by the Free Software Foundation; either version 2
;of the License, or (at your option) any later version.
;
;See file LICENSE for further informations on licensing terms.
;
;This program is distributed in the hope that it will be useful,
;but WITHOUT ANY WARRANTY; without even the implied warranty of
;MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;GNU General Public License for more details.
;
;You should have received a copy of the GNU General Public License
;along with this program; if not, write to the Free Software
;Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,10 USA.
;
;Authors: J. Bresson

(in-package :om)


;;; 3D timed Curve

(defclass 3D-timed-curve (3D-curve) 
  ((times :accessor times :initarg :times :initform nil)
   (color-mode :accessor color-mode :initarg :color-mode :initform 0)))

(defmethod om-draw-contents ((self 3D-timed-curve))
  "Draw a 3D timed curve witgh stroke with and colors"
  (let* ((vertexes (om-get-gl-points self))
         (size (- (length vertexes) 1))
         (vertex-colors (get-vertex-colors self)))
    (opengl:gl-enable opengl:*GL-LIGHT0*)    
    (opengl:gl-line-width (float (line-width self)))
    (when (and (lines self) (> (length (om-3Dobj-points self)) 1))
      (opengl:gl-begin opengl:*GL-LINE-STRIP*))

    (loop for i from 0 to size do
          (if (and (lines self) (> (length (om-3Dobj-points self)) 1))
              (let ((rgb (nth i vertex-colors )))
                (opengl:gl-color4-f (nth 0 rgb) (nth 1 rgb) (nth 2 rgb) 1.0)
                (opengl:gl-vertex4-dv (aref vertexes i)))
            (draw-point-cube (nth i (om-3Dobj-points self)) 0.02 (if (consp (selected-points self))
                                                                     (find i (selected-points self) :test '=)
                                                                   t))
            ))
    (opengl:gl-end)
    (restore-om-gl-colors-and-attributes)
    (when (and (lines self) (> (length (om-3Dobj-points self)) 1))
      (cond ((consp (selected-points self))
             (loop for i in (selected-points self) do 
                   (draw-point-cube (nth i (om-3Dobj-points self)) 0.02 t)))
            ((selected-points self)
             (loop for i from 0 to (- (length vertexes) 1) do                  
                   (draw-point-cube (nth i (om-3Dobj-points self)) 0.02 t)))
            ))
    (restore-om-gl-colors-and-attributes)
    ))

;jgarcia
(defmethod! get-vertex-colors ((self 3d-timed-curve))
            "create a vector of colors for a 3D-timed-curve depending on the mode selected"
            (let ((size (length (oa::points self))))
              (case (color-mode self)
                (1 (loop for i from 0 to (1- size)
                         collect (hsv2rgb (+ min_hue (* (/ (- max_hue min_hue) size) i)) 1.0 1.0)))
                (2 nil)
                (otherwise (make-list size :initial-element (oa::color self))))))

;jgarcia
(defun rgb2hsv (r g b)
  "convert RGB values into HSV values (in float format (0.0 to 1.0))"
  (let* (
         ;be sure we have a correct range for input
         (r (min r 1.0))
         (r (max r 0.0))
         (g (min g 1.0))
         (g (max g 0.0))
         (b (min b 1.0))
         (b (max b 0.0))
         (min_rgb (min r g b))
         (max_rgb (max r g b))
         )
    (if (= min_rgb max_rgb)
        (list 0.0 0.0 min_rgb)
      (progn
        (let* (
               (tmp_d (if (= r min_rgb) (- g b) ( if (= b min_rgb) (- r g) (- b r))))
               (tmp_h (if (= r min_rgb) 3 (if (= b min_rgb) 1 5)))
               (h (/ (* 60 (- tmp_h (/ tmp_d (- max_rgb min_rgb)))) 360))
               (v max_rgb)
               (s (/ (- max_rgb min_rgb) max_rgb)))
          (list h s v))))))


;jgarcia
(defun hsv2rgb (h s v)
  "convert HSV values into RGB values (in float format (0.0 to 1.0))"
    (let* (
           (i (floor (* h 6)))
           (f (- (* h 6) i))
           (p (* v (- 1 s)))
           (q (* v (- 1 (* f s))))
           (tt (* v (- 1 (* (- 1 f) s)))))
      (case (mod i 6) 
        (0 (list v tt p))
        (1 (list q v p))
        (2 (list p v tt))
        (3 (list p q v))
        (4 (list tt p v))
        (5 (list v p q)))))

(defmethod gen-3D-obj ((obj 3D-trajectory) mode line-width)
  (let ((glpoints (format-3d-points obj)))
    (3D-timed-obj-from-points glpoints mode (bpfcolor obj) line-width (times obj))))

(defun 3D-timed-obj-from-points (points drawmode color line-width times)
  (let ((clist (when color (list (float (om-color-r color)) 
                                 (float (om-color-g color)) 
                                 (float (om-color-b color))))))
    (make-instance '3D-timed-curve :points points :color clist :lines drawmode :line-width line-width :times times)))



;;; EDITOR
(defclass traject-editor (3DEditor) 
  ((color-mode-buttons :accessor color-mode-buttons :initarg :color-mode-buttons :initform nil))
  )


(defmethod get-editor-class ((self 3D-trajectory)) 'traject-editor)


(defmethod special-move-point ((self bpcPanel) (point timedpoint) i)
  (let* ((dec (decimals (get-bpf-obj self)))
         (xsize (max 50 (* 10 dec)))
         (mydialog (om-make-window 'om-dialog
                                   :size (om-make-point (max 180 (+ 100 (* 12 dec))) 120)
                                   :window-title ""
                                   :position (om-add-points (om-view-position (window self)) (om-mouse-position self))))
         (xed (om-make-dialog-item 'om-editable-text (om-make-point 30 5) (om-make-point xsize 10)
                                   (if (zerop dec) (format () "~D" (om-point-h point))
                                       (format () (format nil "~S,~DF" '~ dec) 
                                               (/ (om-point-h point) (expt 10.0 dec))))
                                   ))
         (yed (om-make-dialog-item 'om-editable-text (om-make-point 30 35) (om-make-point xsize 10)
                                   (if (zerop dec) (format () "~D" (om-point-v point))
                                       (format () (format nil "~S,~DF" '~ dec) 
                                               (/ (om-point-v point) (expt 10.0 dec))))
                                   ))
         (time-ed (om-make-dialog-item 'om-editable-text (om-make-point 30 65) (om-make-point xsize 10)
                                       (format () "~D" (timedpoint-time point))
                                   ))
         )
    (om-add-subviews mydialog 
                     
                     (om-make-dialog-item 'om-static-text (om-make-point 5 5) (om-make-point 20 20) (x-label self) 
                                          :font *om-default-font3b*
                                          :bg-color *om-window-def-color*)
                     (om-make-dialog-item 'om-static-text (om-make-point 5 35)  (om-make-point 20 20) (y-label self) 
                                          :font *om-default-font3b*
                                          :bg-color *om-window-def-color*)
                     (om-make-dialog-item 'om-static-text (om-make-point 5 65) (om-make-point 20 20) "time" 
                                          :font *om-default-font3b*
                                          :bg-color *om-window-def-color*)
                     xed yed time-ed
                     (om-make-dialog-item 'om-button (om-make-point (- (w mydialog) 80) 5) (om-make-point 70 20) "Cancel"
                                          :di-action (om-dialog-item-act item 
                                                       (declare (ignore item))
                                                       (om-return-from-modal-dialog mydialog ()))
                                          :default-button nil)
                     (om-make-dialog-item 'om-button (om-make-point (- (w mydialog) 80) 36) (om-make-point 70 20) "OK"
                                          :di-action (om-dialog-item-act item 
                                                       (declare (ignore item))
                                                       (let ((tvalue (ignore-errors (read-from-string (om-dialog-item-text time-ed)))))
                                                         (if 
                                                             (move-timedpoints-in-bpf 
                                                              (currentbpf self) 
                                                              (list (list point i)) 
                                                              (- (round (* (read-from-string (om-dialog-item-text xed)) (expt 10.0 dec))) (om-point-h point)) 
                                                              (- (round (* (read-from-string (om-dialog-item-text yed)) (expt 10.0 dec))) (om-point-v point))
                                                              (if (numberp tvalue) tvalue nil))
                                                                  
                                                         (do-after-move self)

                                                         (om-beep-msg "Ilegal move"))
                                                         (om-return-from-modal-dialog mydialog ())))
                                          :default-button t))
    (om-modal-dialog mydialog)))


(defmethod move-timedpoints-in-bpf ((self bpc) points deltax deltay time)
  (let ((legalmove t))
    (loop for point in points do
          (let* ((pos (second point))
                 (tmin (or (list-max (remove nil (mapcar 'get-point-time (subseq (point-list self) 0 pos))))
                           0.0))
                 (tmax (list-min (remove nil (mapcar 'get-point-time (subseq (point-list self) (1+ pos)))))))          
            (if (or (null time)
                    (and (or (equal pos 0) (> time tmin)) 
                         (or (null tmax) (< time tmax))))
                (setf (nth pos (point-list self))
                      (make-timedpoint :point (om-make-point (+ (om-point-h (car point)) deltax)
                                                             (+ (om-point-v (car point)) deltay))
                                       :time time))
              (setf legalmove nil))))
    legalmove))


(defmethod init-tmp-objs ((self traject-editor))
  (call-next-method)
  (set-times-to-tmpobjs self))  

(defmethod editor-change-precision ((self traject-editor) newvalue)
  (call-next-method)
  (set-times-to-tmpobjs self))

(defun set-times-to-tmpobjs (traject-editor)
  (let ((curr3dc (if (multibpf? traject-editor)
                     (if (selected-component traject-editor) (nth (selected-component traject-editor) (bpf-list (object traject-editor)))
                       (car (bpf-list (object traject-editor))))
                   (object traject-editor))))
    (mapcar #'(lambda (tobj)
                (setf (point-list tobj)
                      (loop for pt in (point-list tobj) 
                            for trpoint in (point-list curr3Dc)
                            collect (make-timedpoint 
                                     :point pt
                                     :time (timedpoint-time trpoint))))
                ) (tmpview-objs traject-editor))
    ))

(defmethod report-bpfmodif ((self traject-editor) &key xpts ypts zpts times)
  (let ((3Dobj (if (multibpf? self) (nth (selected-component self) (bpf-list (object self)))
                  (object self))))
    (unless xpts (setf xpts (x-points 3Dobj)))
    (unless ypts (setf ypts (y-points 3Dobj)))
    (unless zpts (setf zpts (z-points 3Dobj)))
    (let ((new-bpf (traject-from-list xpts ypts zpts times 
                                      (type-of 3Dobj) (decimals 3Dobj)
                                      (sample-params 3Dobj) (interpol-mode 3Dobj)
                                       )))
      (cons-bpf 3Dobj (point-list new-bpf))
      ;(setf (traject-points 3Dobj) (traject-points new-bpf))
      )
    (init-tmp-objs self)
    (update-editor-contents self)))


(defmethod more-bpc-draw ((self internalbpcpanel) point pos index)
  (call-next-method)
  (when (and (show-time self) (get-point-time point))
    (om-with-fg-color self *om-red2-color*
    (om-draw-string (+ (om-point-h pos) -6) (+ (om-point-v pos) 14) (format nil "~d" (get-point-time point))))))




(defmethod initialize-instance :after ((self traject-editor) &rest l)
  (declare (ignore l))

  (om-add-subviews (ctrlp self)
                   
                   (om-make-dialog-item 'om-static-text (om-make-point 8 510) (om-make-point 100 40)
                                        "______________"
                                        :font *controls-font*
                                        :fg-color *om-black-color*)
                   (om-make-dialog-item 'om-static-text (om-make-point 8 530) (om-make-point 70 40)
                                        "Sample Rate"
                                        :font *controls-font*
                                        :fg-color *om-black-color*)
                   (om-make-dialog-item 'om-editable-text (om-make-point 70 535) (om-make-point 40 20) 
                                        (format nil " ~a" (sample-params (object self)))
                                        :-action nil
                                        :font *controls-font*
                                        :bg-color *om-white-color*
                                        :modify-action #'(lambda (item)
                                                           (let ((val (ignore-errors (read-from-string (om-dialog-item-text item)))))  
                                                             (when (or (numberp val) (null val) (and (listp val) (list-subtypep val 'number)))
                                                               (setf (sample-params (object self)) val))))
                                        )
                   
                   (om-make-dialog-item 'om-pop-up-dialog-item (om-make-point 8 580) (om-make-point 100 20) ""
                                        :range '("points (constant time)" "distance (constant speed)")
                                        :value (if (equal (interpol-mode (object self)) 'dist) 
                                                   "distance (constant speed)" "points (constant time)")
                                        :di-action (om-dialog-item-act item
                                                      (setf (interpol-mode (object self))
                                                            (if (= (om-get-selected-item-index item) 1) 'dist 'points))))
                   
                   ))

(defmethod add-curve-edit-buttons ((self traject-editor))
  (setf (curve-buttons (ctrlp self))
        (list 
         (om-make-dialog-item 'om-static-text (om-make-point 5 230) (om-make-point 70 20)
                              "Line width"
                              :font *controls-font*
                              :fg-color *om-black-color*)
         (om-make-dialog-item 'edit-numbox (om-make-point 80 230) (om-make-point 30 20) (format nil " ~D" (param-line-width self))
                              :font *controls-font*
                              :bg-color *om-white-color*
                              :value (param-line-width self)
                              :min-val 1.0
                              :max-val 6.0
                              :di-action #'(lambda (item)
                                             (param-line-width  self (value item))
                                             (update-3D-view self)
                                             (om-invalidate-view (3Dp self)))
                              )
         (om-make-dialog-item 'om-static-text (om-make-point 5 260) (om-make-point 70 20)
                              "Color Mode"
                              :font *controls-font*
                              :fg-color *om-black-color*)
         (om-make-dialog-item 'om-pop-up-dialog-item (om-make-point 8 290) (om-make-point 100 20) ""
                              :range '("Simple" "Distance" "Vitesse")
                              :value (case (color-mode (editor-3Dobj self))
                                       ((equal 0) "Simple")
                                       ((equal 1) "Distance")
                                       ((equal 2) "Speed"))
                              :di-action (om-dialog-item-act item
                                           (setf (color-mode (editor-3Dobj self)) (om-get-selected-item-index item))
                                           (update-color-mode-buttons self))
                              )
         ))
  (apply 'om-add-subviews (cons (ctrlp self) (curve-buttons (ctrlp self)))))

(defmethod update-color-mode-buttons ((self traject-editor))
  (when (color-mode-buttons self)
    (apply 'om-remove-subviews (cons (ctrlp self) (color-mode-buttons self))))
  (let ((mode (color-mode (editor-3Dobj self)))
        (_x 5)
        (_y 320))
    (print mode)
    (setf (color-mode-buttons self)
          (case mode
            ((equal 0)
             (list 
             (om-make-dialog-item 'om-static-text (om-make-point _x _y) (om-make-point 70 40)
                                  "Curve color"
                                  :font *controls-font*
                                  :fg-color *om-black-color*)
             (om-make-view 'om-color-view 
                           :position (om-make-point (+ _x 75) _y) 
                           :size (om-make-point 30 22) 
                           :color (bpfcolor (get-current-object self))
                           :after-fun #'(lambda (item) 
                                          (setf (bpfcolor (get-current-object self)) (color item))
                                          (update-3D-view self)
                                          (om-invalidate-view (3Dp self)))
                           )))
            ((equal 1) 
             (list
             (om-make-dialog-item 'om-static-text (om-make-point _x _y) (om-make-point 70 40)
                                  "Distance"
                                  :font *controls-font*
                                  :fg-color *om-black-color*)))
            ((equal 2) 
             (list
             (om-make-dialog-item 'om-static-text (om-make-point _x _y) (om-make-point 70 40)
                                  "Speed"
                                  :font *controls-font*
                                  :fg-color *om-black-color*)))
            )))
    (apply 'om-add-subviews (cons (ctrlp self) (color-mode-buttons self))
    ))


(defmethod get-help-list ((self  3DEditor))
  (remove nil 
          (list '((#+cocoa cmd+clic #-cocoa ctrl+clic "Add point / Draw")
                  (lrud "Move selected points")
                  (del "Delete selected points")
                  (("c") "Change curve color")
                  (("b") "Change 3D background color")
                  (("p") "Show point indices")
                  (("t") "Show point times")
                  )
                (when (multibpf? self)
                  '((tab "Change current curve")
                    (("n") "Change curve name")
                    )))))