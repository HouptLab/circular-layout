
#lang at-exp  racket

(require  scribble/srcdoc)
(require racket/gui/base)

(provide 


(struct*-doc clnode ([name string?] [size number?] [label string?] [color string?])
             @{

              description of a node for circular layout.
              name is the identifier of the node
              size determines the area of the node's circle -- in dc pixels, if scale = 1 -- which is conserved in the area of the node's circle
              label is the string drawn at the center of the node
              color is the string representation of the color used to fill the node (optional: defaults to "white")
              
})



(struct*-doc cledge ([source string?] [target string?] [width number?] [label string?] [directed boolean?])
             @{

              description of an edge between two nodes for circular layout.
              source is the identifier of the source node (matches name of one of the clnodes in accompanying list of nodes)
              target is the identifier of the target node (matches name of one of the clnodes in accompanying list of nodes)
              (if source and target are the same name of a single node, then the edge is a self-edge from that node back to that same node.
              width determines the pen-width of the edge line in pixels (regardless of scale)
              label is the string drawn at the control point of the edge curve
              directed is a boolean flag that determines if an arrow is drawn pointing at target node (optional: defaults to #t)
              
})


(proc-doc/names make-cl-node (->* (#:name string? ) (#:size number? #:label (or/c #f string?) #:color string?) clnode?)
(( name  ) ([size 1] [label #f]  [color "white"]))
@{
   An alternative constructor for a clnode with default size 1, using name as default label and white as default color.
})

(proc-doc/names make-cl-edge (->* (#:source string? #:target string?) (#:label string? #:width number? #:directed boolean?) cledge?)
                (( source  target)( [label ""]  [width 1]  [directed #t]))
                @{

    An alternative constructor for a cledge, with default width of 1, no label, and default as 'directed' (i.e., an arrow is drawn at the target end).
})


(proc-doc/names draw-circular-layout (->* (#:dc (is-a?/c dc<%>)
                                         #:nodes (listof clnode?)
                                         #:edges (listof cledge?)
                                         #:center (cons/c number? number?)
                                         #:scale number?)
                                          ()
                                         void?)
               ( (dc nodes edges center scale) ())
                 @{

                   nodes are drawn with first node at 12 o'clock, with subsequent nodes arranged clockwise,
in same order as in the nodes list
 nodes are spaced at vertices of a polygon with side length (* kScaleSideLength (max node radius))
 ( default is a sidelength 4 x the radius of the largest node )
 edges can be in any order as they reference members of the nodes list


})


) ; provide

#| ------------------------------------------------------------------------------ |#
#| Parameters ------------------------------------------------------------------- |#

(define kScaleSideLength 4)
(define kDrawStraightUndirectedEdges #t)
(define kAngleOffset 1.9) ; half-offset of start-stop angles of self-node arc
(define kRadiusScale 1.1) ; offset of self-node arc from center of the node
(define kSelfRadiusScale 1.7) ; relative size of self-node arc compared to node radius
(define kArrowLength 0.75) ; length of arrow sides relative to scale
(define kUseEdgeWeight #t) ; draw edges with width = weight, otherwise width 1

#| ------------------------------------------------------------------------------ |#

(struct  clnode (name size  label color) )

(struct cledge (source target width label directed))

(define (make-cl-node #:name name #:size [size 1] #:label [label #f] #:color [color "white"])
  (define the-label (if (not label) name  label))
  (clnode name size the-label color))


(define (make-cl-edge #:source source #:target target #:label [label ""] #:width [width 1] #:directed [directed #t])
   (cledge source target width label directed))


#| ------------------------------------------------------------------------------ |#

; nodes are drawn with first node at XX o'clock, with subsequent nodes arranged clockwise,
; in same order as in the nodes list
; nodes are spaced at vertices of a polygon with side length (* kScaleSideLength (max node radius))
; ( default is a sidelength 4 x the radius of the largest node
; edges can be in any order as they reference member of the nodes list

(define (draw-circular-layout #:dc dc #:nodes nodes #:edges edges #:center center #:scale scale)
  
 ; TODO: have draw-nodes return vertices, and reconcile scale and normalize values

 ; (define cl-scale (make-parameter scale))
 ; (parameterize ([cl-scale scale])
  (define nodes-hash (draw-nodes  #:dc dc #:nodes nodes #:center center #:scale scale ))
  (draw-edges #:dc dc #:nodes nodes #:nodes-hash nodes-hash #:edges edges  #:scale scale)
 ;   )
  )

 ; TODO: routine to calculate width and height of resulting layout, so we can set bitmap appropriately
 ; TODO: move constants in parameters? so user can set the parameters before calling?
; TODO: add parameter for drawing edges as straight lines (if undirected) or as splines (if directed)

#| ------------------------------------------------------------------------------ |#

;; return a hash of nodes, keyed by clnode-name, value is (list radius (cons center-x center-y))
;; scaled and centered

(define (nodes->circular-layout #:nodes nodes  #:scale scale #:center center)

  ;; arrange n nodes into a regular polygon
  (define n  (length nodes))
  
  ;; everything is calculated to accomodate the biggest node, so length of polygon sides
  ;; will be kScaleSideLength * the radius of the biggest node
  (define biggest-node-radius (* scale (area->radius  (max-node-size nodes))))
  (define side-length (* kScaleSideLength biggest-node-radius))
  (define p-radius (polygon-radius #:for-sides n #:side-length side-length))
  
;  (writeln (format "unscaled radius ~a" polygon-radius))

  ;; allow margins equal to the radius of the biggest node
  ;; so polygon gets inscribed in a square of side polygon-radius + 2 * biggest-node-radius

  ;; get scaled radius and x,y pairs for center of each node at vertices of polygon

  (for/hash ([i (range 0 n)]
             [node nodes])

    (define node-angle (- (* 2 pi (/ i n)) (/ pi 2)) )
    (define x  (+ (car center)(* p-radius (cos node-angle)) ))
    (define y (+ (cdr center)(* p-radius (sin node-angle )) ))
    (define radius (* scale (area->radius  (clnode-size node))))

    (values (clnode-name node) (list radius (cons x y) node-angle) )
    ))


#| ------------------------------------------------------------------------------ |#



(define (draw-nodes #:dc dc
                    #:nodes nodes
                    #:scale [scale 1]
                    #:center [center '(0 . 0)])


  (define nodes-hash (nodes->circular-layout #:nodes nodes #:scale scale #:center center))

  (send dc set-pen (new pen% [color "black" ] [width 1]))
  (send dc set-smoothing 'aligned) 
  
  (for ([node nodes])

    (send dc set-brush (new brush% [color (clnode-color node) ]))

    (define radius-vertex (hash-ref nodes-hash (clnode-name node)))
    (define radius (first radius-vertex))
    (define node-center (second radius-vertex))
    
    (define node-top-left (offset-pt node-center
                                     (cons (* -1 radius) (* -1 radius))))
    
    (send dc draw-ellipse
          (car node-top-left)
          (cdr node-top-left)
          (* 2 radius)
          (* 2 radius))


    ;; TODO: add support for parsing and laying out \n line breaks in label
    (define-values (tw th ta td) (send dc get-text-extent (clnode-label node)	)) 
    (define label-pt (offset-pt node-center (cons (* -0.5 tw) (* -0.5 th))))
    (send dc draw-text (clnode-label node)  (car label-pt) (cdr label-pt))
      
    
    )
  nodes-hash
  )


#| ------------------------------------------------------------------------------ |#

;; draw an edge between the 2 nodes, taking into account the node  sizes
;; edge can have an optional width


; need to pass in scale for offsets and control-points
(define (draw-edges #:dc dc #:nodes nodes #:nodes-hash nodes-hash #:edges edges #:scale scale)

  
  (send dc set-brush (new brush% [style 'transparent]))
  (send dc set-smoothing 'aligned) 

  (for ([e edges])

    ; set width of edge
   (cond [kUseEdgeWeight
         (send dc set-pen (new pen% [color "darkgray" ] [width (cledge-width e)]))]
         [else
          (send dc set-pen (new pen% [color "darkgray" ] [width 1]))])
  

    (define source-name (cledge-source e))
    (define target-name (cledge-target e))
    (define source-r-v (hash-ref nodes-hash source-name))
    (define target-r-v (hash-ref nodes-hash target-name))

    ;  take into account the size of the nodes and their scale,
    ; and offset edges to start and end on circumference of nodes

    (define source-radius (first source-r-v))
    (define target-radius (first target-r-v))

    (define source-vertex (second source-r-v))
    (define target-vertex (second target-r-v))

    (define source-angle (third source-r-v))
   

    (cond [(equal? source-name target-name)
           (draw-self-edge #:dc dc
                           #:radius source-radius
                           #:vertex source-vertex
                           #:angle source-angle
                           #:label (cledge-label e)
                           #:scale scale
                           #:directed (cledge-directed e)
                           )]
          [else 

           (draw-edge #:dc dc
                      #:souce-radius source-radius
                      #:target-radius target-radius
                      #:source-center source-vertex 
                      #:target-center target-vertex
                      #:label (cledge-label e)
                      #:scale scale
                      #:directed (cledge-directed e)
                      )])))

#| ------------------------------------------------------------------------------ |#

; need to pass scale for offsets and control-point
(define (draw-edge #:dc dc
                   #:souce-radius source-radius
                   #:target-radius target-radius
                   #:source-center source-vertex 
                   #:target-center target-vertex
                   #:label label
                   #:scale scale
                   #:directed [directed #t])

  (define edge-angle (2points->angle source-vertex target-vertex))

  ; move perpendicular to edge angle by perp-offset pixels
  ; TODO: make perp-offset a multiple of line-width?
  (define perp-angle (+ edge-angle (/ pi 2)))
  (define perp-offset (/ 3 scale))
  (define dx (if (and (not directed) kDrawStraightUndirectedEdges) 0 (* perp-offset (cos perp-angle))))
  (define dy (if (and (not directed) kDrawStraightUndirectedEdges) 0 (* perp-offset (sin perp-angle))))
  
  (define source-offset (cons  (+ (*  -1 source-radius (cos edge-angle))
                                  dx)
                               (+ (*  -1 source-radius (sin edge-angle))
                                  dy)))
    
  (define target-offset (cons  (+ (*  target-radius (cos edge-angle))
                                  dx)
                               (+ (*  target-radius (sin edge-angle))
                                  dy)))

  (define source-pt (offset-pt source-vertex source-offset) )

  (define target-pt (offset-pt target-vertex target-offset) )

  ; TODO: get magnitude of control-point-offset in a principled way (e.g. as proportion of layout radius?
  ; find control point in unscaled layout, then scale and center

    (define control-point-offset scale)
    (define control-pt  (mid-offset-point source-pt target-pt control-point-offset))


   ( cond 
          [(and (not directed) kDrawStraightUndirectedEdges)
           (send dc draw-line (car source-pt) (cdr source-pt) (car target-pt) (cdr target-pt))]
          [else 
      (send dc draw-spline (car source-pt) (cdr source-pt) (car control-pt) (cdr control-pt) (car target-pt) (cdr target-pt))])

  ( cond [directed 

  ; source -> target
  (define tangent-angle  (2points->angle target-pt control-pt))
  (draw-arrow #:dc dc #:pt target-pt #:angle tangent-angle  #:scale scale ) ])

  ; TODO: offset label from control pt in direction perpendicular to edge
  (define-values (tw th ta td) (send dc get-text-extent label	)) 
  ;  (define label-pt (offset-pt (mid-offset-point source-pt target-pt th ) (cons ( * -0.5 tw) 0)))
  (define label-pt (offset-pt control-pt (cons (+ dx ( * -0.5 tw)) (+ dy ( * -0.5 th)))))
          
  (send dc draw-text label  (car label-pt) (cdr label-pt))

  ) 

#| ------------------------------------------------------------------------------ |#

  
(define (draw-self-edge #:dc dc #:radius radius #:vertex vertex #:angle node-angle #:label label #:scale scale #:directed [directed #t])

  ;; draw an arc on outerside of node that points back to the node itself.
  ;; arc is 0.5 radius of node, with center point on circumference of node

  ; because vertex is placed on edge of unit-circle, we can figure out the angle from node to center
  ; and put arrow on outer side of the node

  ; radius is already scaled, vertex is already scaled and centered

  ; radius of arc
  
  (define self-radius (/ radius kSelfRadiusScale))
  (define self-diameter (* 2 self-radius))
  
  ;; get center of arc
  
  (define arc-offset (cons (*   (* kRadiusScale radius) (cos node-angle))
                           (*   (* kRadiusScale radius) (sin node-angle))))
  (define arc-center (offset-pt vertex arc-offset))

  (define side-offset (cons (*   self-radius (cos (+ node-angle kAngleOffset)))
                            (*   self-radius (sin (+ node-angle  kAngleOffset)))))
  (define side-pt (offset-pt arc-center side-offset))


  (define side1-angle (tween-0-2pi (* -1 (- node-angle kAngleOffset))))
  (define side2-angle (tween-0-2pi (* -1 (+ node-angle kAngleOffset ))))

  (define arc-angles (get-arc-angles side1-angle  side2-angle))


  (define arc-top-left (offset-pt arc-center (cons (* -1 self-radius) (* -1 self-radius) )))


  (send dc draw-arc
        (car arc-top-left)
        (cdr arc-top-left)
        self-diameter
        self-diameter        
    
        (car arc-angles)
        (cdr arc-angles)
       
        )

  (cond [directed 
  ;; TODO: find tangent angle of arc at side-pt, so we can set arrow angle precisely?
  (draw-arrow #:dc dc #:pt side-pt #:angle (+ (* 0.96875 pi ) node-angle) #:scale scale ) ; (/ 7.75 8) = 0.96875 works ok
  ])

  (define-values (tw th ta td) (send dc get-text-extent label	)) 

  (define label-offset (cons  (+ (* -0.5 tw)(*   (+ ( * 0.5 tw) self-radius) (cos node-angle)))
                              (+ (* -0.5 th)(* (+   ( * 0.5 th) self-radius) (sin node-angle)))))
  
  (define label-pt (offset-pt arc-center label-offset))
          
  (send dc draw-text label  (car label-pt) (cdr label-pt))
  

  )



#| ------------------------------------------------------------------------------ |#



(define (draw-arrow #:dc dc #:pt pt #:angle angle #:scale [scale 1])

  (define length (* kArrowLength scale))
  
  (define left-angle (+ angle (* pi .85)))
    
  (define  right-angle (- angle (* pi .85)))

  (define left-offset (cons (* length (cos left-angle))
                            (* length (sin left-angle))))

  (define right-offset (cons  (* length (cos right-angle))
                              (* length (sin right-angle))))

  (define left-pt (offset-pt pt left-offset))
  (define right-pt (offset-pt pt right-offset))

  (send dc draw-line (car pt) (cdr pt)  (car left-pt) (cdr left-pt))
  (send dc draw-line (car pt) (cdr pt)  (car right-pt) (cdr right-pt)))

#| ------------------------------------------------------------------------------ |#
#| ------------------------------------------------------------------------------ |#
#| Utility Functions ------------------------------------------------------------ |#


;; given pt and center as '( x . y), and scale as number, return a new '( x . y) centered and scaled
(define (scale-and-center pt scale center)
  (cons  (+ (car center) (* scale (car  pt))) (+ (cdr center) (*  scale (cdr  pt))))) 

(define (offset-pt pt offset)
  (cons (+  (car offset) (car pt)) (+ (cdr offset) (cdr pt))))

#| ------------------------------------------------------------------------------ |#

;; given a side-length of an n-sided polygon, get the radius of the polygon
(define (polygon-radius #:for-sides n #:side-length side)
  (define angle-per-side (/ (* 2.0 pi) n))
  (/ side (* 2 (sin (/ angle-per-side 2.0)))))


#| ------------------------------------------------------------------------------ |#
;; convert a node size (i.e. area) to a radius of the circle with that area
(define (area->radius area)
  (sqrt (/ area pi)))

(define (sum-node-sizes nodes)
  (foldl + 0 (map second nodes)))

(define (max-node-size nodes)
  (apply max (map (lambda (x) (clnode-size x)) nodes)))

#| ------------------------------------------------------------------------------ |#

; find angle subtended by two points relative to a vertex point

(define (3points->angle v pt1 pt2)
   
  (define adj1-length  (sqrt (+ (sqr (- (car v) (car pt1)))  (sqr (- (cdr v) (cdr pt1))))))
  (define adj2-length  (sqrt (+ (sqr (- (car v) (car pt2)))  (sqr (- (cdr v) (cdr pt2))))))
  (define opp-length   (sqrt (+ (sqr (- (car pt1) (car pt2)))  (sqr (- (cdr pt1) (cdr pt2))))))

  (acos (/
         (+ (sqr adj1-length) (sqr adj2-length) (* -1 (sqr opp-length)))
         (* 2 adj1-length adj2-length)
         )
        )
  )

#| ------------------------------------------------------------------------------ |#

; find angle formed by the line from (0,0) to a point; angle will be relative to y=0 line
(define (1point->angle pt)

  (cond [(=  (car pt) 0) 0.0]
        [else (atan  (cdr pt)  (car pt))]))

#| ------------------------------------------------------------------------------ |#
; find angle formed by the line between 2 points; angle will be relative to y=0 line
(define (2points->angle pt1 pt2)

  (cond [(=  (car pt1) (car pt2)) 0.0]
        [else (atan (- (cdr pt1) (cdr pt2)) (- (car pt1) (car pt2)))]))

#| ------------------------------------------------------------------------------ |#
; normalize x to be 0 <= x < 2pi
(define (tween-0-2pi  x)
  (cond [(and  (<= 0 x ) (< x (* 2 pi) ) ) x]
        [(< (* 2 pi) x) (tween-0-2pi (- x (* 2 pi)))]
        [(<  x 0 ) (tween-0-2pi (+ x (* 2 pi)))]))

#| ------------------------------------------------------------------------------ |#

; calculate distance between a and b
(define (distance a b)
  (define dy (- (cdr b) (cdr a)))
  (define dx (- (car b) (car a )))
  (sqrt (+ (* dx dx) (* dy dy))))
  
; find midpoint of line a->b
(define (midpoint a b)
  (cons (/ (+ (car a) (car b)) 2) (/ (+ (cdr a) (cdr b)) 2)))

; find a point offset along line perpendicular at the midpoint to a->b 
(define (mid-offset-point a b d)
  (let* ((mid (midpoint a b))
         (theta (2points->angle a b))
         (perp-angle (+ theta (/ pi 2)))
         (dx (* d (cos perp-angle)))
         (dy (* d (sin perp-angle))))
    (cons (+ (car mid) dx) (+ (cdr mid) dy))))

#| ------------------------------------------------------------------------------ |#
; babylonian tablet BM 85194
; https://math.stackexchange.com/questions/3936542/finding-the-perpendicular-distance-from-a-chord-to-the-circumference
; Let C be the center of the circle, M be the midpoint of the chord,
; and A be one endpoint of the chord.
; OC = sqrt(OA^2 - CA^2)

(define (chord-to-circle a b center)
  (define m-ab (midpoint a b))
  (define AC (distance a center))
  (define MC (distance m-ab center))
  (sqrt (+ (* AC AC) (* MC MC))))

#| ------------------------------------------------------------------------------ |#

; make sure a and b are between 0 and 2 pi, and ( < a b), so b greater than a

(define (get-arc-angles a  b) 
  (define ( do-get-start-end-angles a b)
    (cond [ ( < pi (- b a)) (cons a b)]
          [else (cons ( - b (* 2 pi)) a )]))
  ( if ( < a b)
       ( do-get-start-end-angles a b)
       ( do-get-start-end-angles b a)))


#| ------------------------------------------------------------------------------ |#

