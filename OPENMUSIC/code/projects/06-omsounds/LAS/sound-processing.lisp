(in-package :om)

;======================================================
;SND Process boxes relying on LibAudioStream
;======================================================
; J. Bresson 2005
;======================================================

;;; TODO : TEST IF LIBAUDIOSTREAM IS LOADED
;; E.G. #+LIBAUDIOSTREAM

(defclass sound-data (simple-container)
  ((ptr :accessor ptr :initform nil :initarg :ptr)
   (tracknum :accessor tracknum :initform 1 :initarg :tracknum)))


(defmethod! Sound-Play ((s sound-data))
  :icon 207
  (when (ptr s)
    (las-play (make-instance 'om-sound :sndlasptr-current (ptr s) :loaded t
                             :number-of-channels (las::GetChannelsSound (ptr s))))
    ))


(defmethod get-obj-dur ((self sound-data)) (round (las::GetLengthSound (ptr self)) 44.1))

(defmethod extent->ms ((self sound-data)) (round (las::GetLengthSound (ptr self)) 44.1))


(defmethod allowed-in-maq-p ((self sound-data)) t)

;;(defmethod get-editor-class ((self sound-data)) 'soundEditor)
(defmethod Class-has-editor-p ((self sound-data)) nil)

(defmethod sound-get-pict ((self sound-data))
   (om-cons-snd-pict (ptr self)))

(defmethod! get-sound-data ((self sound))
  :icon 221
  (and (om-sound-file-name self)
       (make-instance 'sound-data 
                      :ptr (las::MakeReadSound (om-path2cmdpath (om-sound-file-name self)))
                      :tracknum (tracknum self))))

(defmethod! get-sound-data ((self string))
  :icon 221
  (make-instance 'sound-data 
                 :ptr (las::MakeReadSound (om-path2cmdpath self))
                 :tracknum 0))

(defmethod! get-sound-data ((self pathname))
  :icon 221
  (get-sound-data (namestring self)))

;;;=======================================
;;; SAVE SOUND
;;;=======================================
(defun save-sound-in-file (snd filename &optional (format nil))
  (let* ((sndformat (or format *def-snd-format*))
         (resolution (case *audio-res*
                       (8 las::SF_FORMAT_PCM_S8)
                       (16 las::SF_FORMAT_PCM_16)
                       (24 las::SF_FORMAT_PCM_24)
                       (32 las::SF_FORMAT_PCM_32)              
                       (otherwise las::SF_FORMAT_PCM_16)))
         (sndr (las::MakeRendererSound (las::MakeWriteSound (om-path2cmdpath filename) snd 
                                                            (if (equal sndformat 'aiff)
                                                                (logior las::SF_FORMAT_AIFF resolution)
                                                              (logior las::SF_FORMAT_WAV resolution)))))
         (buffer-size 512)
         (buffer (om-make-pointer (* 4 buffer-size 2) t))    
         (res buffer-size))
    ;(las::ResetSound sndr)
    (loop while (= res buffer-size) do
          ;(setf res (las::ReadSound sndr buffer buffer-size (las::GetChannelsSound sndr)))
          (setf res (las::ReadSound sndr buffer buffer-size 2))
          )
    (om-free-pointer buffer)
    )
  (probe-file filename))

(defmethod! save-sound ((self sound-data) filename &optional (format 'aiff))
  :icon 107
  :initvals '(nil nil 'aiff)
  :indoc '("a sound data pointer" "output file pathname" "audio format")
  :menuins '((2 (("AIFF" 'aiff) ("WAV" 'wav))))
  :doc "Saves a 'sound-data' pointer as an audio file.

'sound-data' pointers are generated by the OM/LibAudioStream sound processing functions.
"
  (let ((sndformat (or format *def-snd-format*))
        (file (or filename (om-choose-new-file-dialog :directory (def-save-directory) 
                                                      :prompt (om-str "Save as...")
                                                      :types (cond ((equal format 'aiff) (list (format nil (om-str :file-format) "AIFF") "*.aiff;*.aif"))
                                                                   ((equal format 'wav) (list (format nil (om-str :file-format) "WAV") "*.wav"))
                                                                   (t nil))))))
        (when file
          (setf *last-saved-dir* (make-pathname :directory (pathname-directory file)))
          (save-sound-in-file (ptr self) file format))))

(defmethod! save-sound ((self sound) filename &optional (format 'aiff))
  (save-sound (get-sound-data self) filename format))


(defmethod* objfromobjs ((self sound-data) (type sound))
   (let ((snd (save-sound self nil)))
     (when snd (load-sound-file snd))))


;;;=======================================
;;; RECORD SOUND
;;;=======================================

(defparameter *audio-recorder* nil)
(defparameter *temp-recorded-file* nil)

(defun las-audio-format (resolution format)
  (let* ((sndformat (or format *def-snd-format*))
         (lasformat (if (equal sndformat 'aiff)  las::SF_FORMAT_AIFF las::SF_FORMAT_WAV))
         (sndres (or resolution *audio-res*))
         (lasres (case sndres
                       (8 las::SF_FORMAT_PCM_S8)
                       (16 las::SF_FORMAT_PCM_16)
                       (24 las::SF_FORMAT_PCM_24)
                       (32 las::SF_FORMAT_PCM_32)              
                       (otherwise las::SF_FORMAT_PCM_16))))
    (logior lasformat lasres)))
                                                           

(defun las-start-audio-record (&optional file resolution format)
  (if *audio-recorder*
      (om-beep-msg "Already recording !!") 
    (let ()
      (setf *temp-recorded-file* 
            (or file (om-choose-new-file-dialog :prompt "Choose a name and location for the recorded audio file"
                                                :directory (outfile nil))))
      (when *temp-recorded-file*
        (setf *audio-recorder* (las::OpenAudioPlayer 2 2 32 *audio-sr* 1024 65536  65536 las::kPortAudioRenderer 1))
        (handler-bind ((error #'(lambda (err)
                                  (om-message-dialog err)
                                  (las::StopAudioPlayer *audio-recorder*)
                                  (las::CloseAudioPlayer *audio-recorder*)
                                  (setf *audio-recorder* nil)
                                  (om-abort)
                                  )))
          (let* ((iastream (las::MakeInputSound))
                 (writesnd (las::MakeWriteSound (namestring *temp-recorded-file*) iastream
                                                (las-audio-format resolution format))))
            (las::LoadChannel *audio-recorder* writesnd 1 1.0 1.0 1.0)
            (las::StartAudioPlayer *audio-recorder*)
            (print "Start recording")
            (las::StartChannel *audio-recorder* 1))
          t)))))

(defun las-stop-audio-record ()
  (when *audio-recorder*
    (print "Stop recording")
    (las::StopChannel *audio-recorder* 1)
    (las::StopAudioPlayer *audio-recorder*)
    (las::CloseAudioPlayer *audio-recorder*)
    (setf *audio-recorder* nil)
    (sys::gc-all)
    *temp-recorded-file*))

(defmethod! record-sound (dur &optional file resolution format)
  :icon 108
  :initvals '(1000 nil nil nil)
  :indoc '("rec duration (ms)" "output file" "resolution (8/16/24/32)" "format (wav/aiff)")
  :outdoc '("recorded file pathname")
  (las-start-audio-record file resolution format)
  (sleep (/ dur 1000.0))
  (las-stop-audio-record))

;;;=========================
;;; BOXES
;;;=========================

;;;---- MIX ----

(defmethod! sound-mix ((s1 sound-data) (s2 sound-data))
  :icon 101
  :initvals '(nil nil)
  :indoc '("a sound or sound-data pointer" "a sound or sound-data pointer")
  :doc "Generates a mix of <s1> and <s2>. 

SOUND-MIX is part of the audio processing tools based on the LibAudioStream library (see http://libaudiostream.sourceforge.net/).
It generates an abstract sound pointer (called 'sound-data' in OM) which can undergo further processing or be saved as a sound file using SAVE-SOUND function.
"
  (make-instance 'sound-data 
    :ptr (las::MakeMixSound (ptr s1) (ptr s2))
    :tracknum (tracknum s1)))

(defmethod! sound-mix ((s1 sound) (s2 sound))
  (sound-mix (get-sound-data s1) (get-sound-data s2)))

(defmethod! sound-mix ((s1 sound-data) (s2 sound))
  (sound-mix s1 (get-sound-data s2)))

(defmethod! sound-mix ((s1 sound) (s2 sound-data))
  (sound-mix (get-sound-data s1) s2))


;;;---- SILENCE ----

(defmethod! sound-silence ((dur float))
  :icon 105
  :initvals '(1.0)
  :indoc '("duration (float or interger)")
  :doc "Generates a silence of duration = <dur>.

<dur> is considered to be in seconds if a float number is given (e.g. 20.0) or in milliseconds if integer (e.g. 20).

SOUND-SILENCE is part of the audio processing tools based on the LibAudioStream library (see http://libaudiostream.sourceforge.net/).
It generates an abstract sound pointer (called 'sound-data' in OM) which can undergo further processing or be saved as a sound file using SAVE-SOUND function.

Note: typically, SOUND-SILENCE is used in order to add silence before or between sounds concatenated with SOUND-SEQ.
"
  (make-instance 'sound-data 
    :ptr (las::MakeNullSound (round (* dur *audio-sr*)))
    ))

(defmethod! sound-silence ((dur integer))
  (make-instance 'sound-data 
    :ptr (las::MakeNullSound (round (* dur (* *audio-sr* 0.001))))))


;;;---- SEQ ----

(defmethod! sound-seq ((s1 sound-data) (s2 sound-data) &optional (crossfade 0))
    :icon 100
    :initvals '(nil nil 0)
    :indoc '("a sound or sound-data pointer" "a sound or sound-data pointer" "cross-fading duration (ms)")
  "Concatenates <s1> and <s2>. 

<crossfade> (duration in milliseconds) determines a fade-in/fade out overlapping between the sounds. 

SOUND-SEQ is part of the audio processing tools based on the LibAudioStream library (see http://libaudiostream.sourceforge.net/).
It generates an abstract sound pointer (called 'sound-data' in OM) which can undergo further processing or be saved as a sound file using SAVE-SOUND function.
"
  (make-instance 'sound-data 
    :ptr (las::MakeSeqSound (ptr s1) (ptr s2) (round (* crossfade (* *audio-sr* 0.001))))
    :tracknum (tracknum s1)))

(defmethod! sound-seq ((s1 sound-data) (s2 sound) &optional (crossfade 0))
  (sound-seq s1 (get-sound-data s2) crossfade))

(defmethod! sound-seq ((s1 sound) (s2 sound-data) &optional (crossfade 0))
  (sound-seq (get-sound-data s1) s2 crossfade))

(defmethod! sound-seq ((s1 sound) (s2 sound) &optional (crossfade 0))
  (sound-seq (get-sound-data s1) (get-sound-data s2) crossfade))


;;;---- FADE ----

(defmethod! sound-fade ((s sound-data) in out)
    :icon 102
    :initvals '(nil 100 100)
    :indoc '("a sound or sound-data pointer" "fade in duration (ms)" "fade out duration (ms)")
  "Generates a fade-in and/or fade-out effect on <s>. 

SOUND-FADE is part of the audio processing tools based on the LibAudioStream library (see http://libaudiostream.sourceforge.net/).
It generates an abstract sound pointer (called 'sound-data' in OM) which can undergo further processing or be saved as a sound file using SAVE-SOUND function.
"
  (make-instance 'sound-data 
    :ptr (las::MakeFadeSound (ptr s) (round (* in (* *audio-sr* 0.001))) (round (* out (* *audio-sr* 0.001))))
    :tracknum (tracknum s)))

(defmethod! sound-fade ((s sound) in out)
  (sound-fade (get-sound-data s) in out))


;;;---- LOOp ----

(defmethod! sound-loop ((s sound-data) n)
  :icon 103
  :initvals '(nil 3)
  :indoc '("a sound or sound-data pointer" "a number")
  "Generates a <n>-times repetition of <s>. 

SOUND-LOOP is part of the audio processing tools based on the LibAudioStream library (see http://libaudiostream.sourceforge.net/).
It generates an abstract sound pointer (called 'sound-data' in OM) which can undergo further processing or be saved as a sound file using SAVE-SOUND function.
"
  (make-instance 'sound-data 
    :ptr (las::MakeLoopSound (ptr s) n)
    :tracknum (tracknum s)))

(defmethod! sound-loop ((s sound) n)
  (sound-loop (get-sound-data s) n))


;;;---- CUT ----
;;; en MS
(defmethod! sound-cut ((s sound-data) beg end)
  :icon 104
  :initvals '(nil 0 1000)
  :indoc '("a sound or sound-data pointer" "begin time (ms)" "end time (ms)")
  "Cuts and returns an extract between <beg> and <end> in <s>.

SOUND-CUT is part of the audio processing tools based on the LibAudioStream library (see http://libaudiostream.sourceforge.net/).
It generates an abstract sound pointer (called 'sound-data' in OM) which can undergo further processing or be saved as a sound file using SAVE-SOUND function.
"
  (make-instance 'sound-data 
    :ptr (las::MakeCutSound (ptr s) (round (* beg (* *audio-sr* 0.001))) (round (* end (* *audio-sr* 0.001))))
    :tracknum (tracknum s)))

(defmethod! sound-cut ((s sound) beg end)
  (sound-cut (get-sound-data s) beg end))


;;;---- EFFECTS ----

(defmethod! sound-vol ((s sound-data) gain &optional (in 1) (out 1))
  :icon 106
  :initvals '(nil 1.0 100 100)
  :indoc '("a sound or sound-data pointer" "a gain value" "fade in duration (ms)" "fade out duration (ms)")
  "Adds gain effect (volume) on <s>. 

<gain> is a multiplicative factor to the sound sample values.
<in> and <out> determine fade-in / fade-out periods for the gain effect.

SOUND-VOL is part of the audio processing tools based on the LibAudioStream library (see http://libaudiostream.sourceforge.net/).
It generates an abstract sound pointer (called 'sound-data' in OM) which can undergo further processing or be saved as a sound file using SAVE-SOUND function.
"
  (make-instance 'sound-data 
    :ptr (las::MakeTransformSound (ptr s) 
                                 (las::AddAudioEffect (las::MakeAudioEffectList) (las::MakeVolAudioEffect (float gain))) 
                                 (round (* in (* *audio-sr* 0.001))) (round (* out (* *audio-sr* 0.001))))
    :tracknum (tracknum s)))

(defmethod! sound-vol ((s sound) gain &optional (in 1) (out 1))
  (sound-vol (get-sound-data s) gain in out))


(defmethod! sound-effect ((s sound-data) effects &optional (in 1) (out 1))
  :icon 106
  (let ((aelist (las::MakeAudioEffectList))
        (newfx (list! effects)))
    (loop for fx in newfx do (setf aelist (las::AddAudioEffect aelist fx)))
    (make-instance 'sound-data 
                   :ptr (las::MakeTransformSound (ptr s) 
                                                aelist 
                                                (round (* in (* *audio-sr* 0.001))) (round (* out (* *audio-sr* 0.001))))
                   :tracknum (tracknum s))))

(defmethod! sound-effect ((s sound) effects &optional (in 1) (out 1))
  (sound-effect (get-sound-data s) effects in out))


(defmethod! vol-effect (gain)
  :icon 106
  :initvals '(1)
  (las::MakeVolAudioEffect (float gain)))

(defmethod! pan-effect (pan)
  :icon 106
  :initvals '(0.5)
  (las::MakeMonoPanAudioEffect (float pan)))

(defmethod! stereo-pan-effect (panL panR)
  :icon 106
  :initvals '(0 1)
  (las::MakeStereoPanAudioEffect (float panL) (float panR)))


;;;---- CONVERSION ----

(defmethod objfromobjs ((self sound) (type sound-data)) 
  (objfromobjs (save-sound self nil) type)) 





 