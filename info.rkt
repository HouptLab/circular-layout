#lang info
(define collection "circular-layout")
(define version "1.0")
(define scribblings '(("scribblings/circular-layout.scrbl")))
(define pkg-desc "A lightweight module for drawing nodes and edges in a circular layout.")
(define license '(MIT))
(define pkg-authors '(houpt@bio.fsu.edu))
(define deps '("base"
               "gui-lib"
               "scribble-lib"))
(define build-deps '("at-exp-lib"
                     "draw-doc"
                     "racket-doc"))
