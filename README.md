Parses heapsnapshot files from node.js and Chrome V8.

Install
=======

[![Greenkeeper badge](https://badges.greenkeeper.io/jwalton/node-heapsnapshot-parser.svg)](https://greenkeeper.io/)

npm install --save heapsnapshot-parser

Usage
=====

    var fs = require('fs');
    var parser = require('heapsnapshot-parser');

    var snapshotFile = fs.readFileSync(filename, {encoding: "utf-8"});
    var snapshot = parser.parse(snapshotFile);

    for (var i = 0; i < snapshot.nodes.length; i++) {
        var node = snapshot.nodes[i];
        console.log(node.toShortString());
    }

API
===

parse(snapshot, options)
------------------------

Returns a new `HeapSnapshot` object.

If `options.reporter()` is provided, `reporter({message})` will be called throughout the parsing
process to indicate progress.

Snapshot
--------

The snapshot returned from `parse()` has the following properties:

* `nodes` - an array of Node objects, one for every object found in the heap snapshot.
* `nodesById` - a hash of Node objects, indexed by their ID.
* `edges` - an array of Edge objects, one for every edge found in the heap snapshot.

Node
----

All properties from the node present in the heapsnapshot file are copied directly to the Node object.
This includes:

* `type` - (string) The type of the object.
* `name` - (string) The name of the object.
* `id` - (integer) A unique numeric ID for the object.
* `self_size` - (integer) Size of the object in bytes, not including any referenced objects.
* `trace_node_id` - ???

In addition, each node has the following properties:

* `references` - An array of Edge objects for nodes which this node references.
* `referrers` - An array of Edge objects for nodes which reference this object.

### Node.getProperty(name, edgeType='property')

If this Node has a reference to another Node of the specified name and edgeType, returns the Node.
Returns `null` otherwise.

### Node.toString()

Returns a string representation of this node.

### Node.toShortString()

Returns a one-line string representation of this node.

Edge
----

All properties from the edge present in the heapsnapshot file (except `to_node`) are copied
directly to the Edge object.  This includes:

* `type` - (string) The type of the edge.
* `name_or_index` - (string) The name (or index, for an array element) for this edge.

In addition, each node has the following properties:

* `fromNode`, `toNode` - Node objects for the referring and referred object for this edge.

### Edge.toString()

Returns a string representation of this edge.


TODO
====

* Reading a really huge file fails.  See [Reading large files in node.js](https://coderwall.com/p/ohjerg/read-large-text-files-in-nodejs).

Suggested Reading
=================

Some articles about how objects are represented in V8:

* [A Tour of V8 Object Representation](http://jayconrod.com/posts/52/a-tour-of-v8-object-representation)
* [v8-profiler.h](https://github.com/v8/v8/blob/master/include/v8-profiler.h) has some documentation about the heap dump format (but, not a lot.)
* [heap-snapshot-generator.cc](https://github.com/v8/v8/blob/master/src/heap-snapshot-generator.cc)
