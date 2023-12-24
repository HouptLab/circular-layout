# circular-layout

A lightweight Racket module which draws a graph of nodes and edges in a circular layout, as an alternative to more powerful graph-rendering e.g. graphviz.

Nodes are defined using *make-cl-node* (which sets a name, size, a label and color), and edges are defined using *make-cl-edge* (which defines the source and target nodes, the weight of the edge, a label, and whether the edge is directed, i.e. has an arrow). A list of these nodes and edges are passed to *draw-circular-layout* along with a destination drawing context (dc<%>); scale factor and center of the graph is also specified.

## Example usage

## Example output


