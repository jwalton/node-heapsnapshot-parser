fs = require 'fs'
ld = require 'lodash'

# Takes an array `fields` of field names, and an array `values` with a length which is a
# multiple of `fields.length`, and returns the resulting objects.
#
# `constructor` must take the parameters `(snapshot, json)`.
parseObjects = (snapshot, values, fields, constructor) ->
    answer = []
    valueIndex = 0
    while valueIndex < values.length
        fieldIndex = 0
        obj = {}
        while fieldIndex < fields.length
            obj[fields[fieldIndex]] = values[valueIndex]
            fieldIndex++
            valueIndex++

        if constructor?
            answer.push new constructor snapshot, obj
        else
            answer.push obj

    return answer

fillObjectType = (name, object, types) ->
    if object.type?
        if object.type > types.length
            throw new Error "Type #{object.type} out of range (#{types.length}) for #{name}."
        object.type = types[object.type]

    return object

parseNodes = (snapshot) ->
    nodes = parseObjects snapshot, snapshot.nodes, snapshot.snapshot.meta.node_fields, Node

parseEdges = (snapshot) ->
    edges = parseObjects snapshot, snapshot.edges, snapshot.snapshot.meta.edge_fields, Edge

parseSnapshot = (snapshot, options={}) ->
    options.reporter? {message: "Parsing nodes"}
    nodes = parseNodes snapshot

    options.reporter? {message: "Parsing edges"}
    edges = parseEdges snapshot

    # Hook up edges to their `toNode`s
    options.reporter? {message: "Connecting edges to destination nodes"}
    for edge in edges
        toNode = nodes[edge.toNodeIndex]
        edge.toNode = toNode
        toNode.referrers.push edge

    # Hook up edges to their `fromNode`s.
    # If we read all the nodes in-order, then the edges they "own" are the next `edge_count` edges.
    options.reporter? {message: "Connecting edges to origin nodes"}
    edgeIndex = 0
    for node, nodeIndex in nodes
        nodeEdgeIndex = 0
        while nodeEdgeIndex < node.edge_count
            if edgeIndex >= edges.length then throw new Error "Ran out of edges!"
            edge = edges[edgeIndex]
            node.references.push edge
            edge.fromNode = node
            edgeIndex++
            nodeEdgeIndex++

    return {nodes, edges}

MAX_STRING_LEN_TO_PRINT = 40

# These are edge types we follow when we're computing the retained size of an object.
#
# Descriptions here are from v8-profiler.h:
#
# * 'context' edges are "A variable from a function context".
# * 'element' is "An element of an array".  TODO: How is this different from "property"?
# * 'property' is a named object property (an element in an array or an actual property.)
# * 'internal' are for references to objects that the V8 engine uses internally.  These
#   are things like "maps" (see http://jayconrod.com/posts/52/a-tour-of-v8-object-representation.)
#   These are technically part of the retained size, but they aren't very interesting, and
#   they can take a lot of time to traverse, so we ignore them.
# * 'hidden' is "A link that is needed for proper sizes calculation, but may be hidden from user."
#   so we follow them.
# * 'shortcut' is "A link that must not be followed during sizes calculation." ???
# * 'weak' is a weak reference - we don't follow these for retained size, since this object is not
#   actually retaining the object.
#
RETAINED_SIZE_EDGES = ['context', 'element', 'property', 'hidden']

class Node
    constructor: (snapshot, json) ->
        for key, value of json
            this[key] = value

        if @name? then @name = snapshot.strings[@name]
        fillObjectType "node", this, snapshot.snapshot.meta.node_types[0]

        @references = []
        @referrers = []

    toShortString: ->
        name = @name
        if @type is 'string'
            name = name.replace /\n/g, '\\n'
            if name.length > MAX_STRING_LEN_TO_PRINT then name = name[0...(MAX_STRING_LEN_TO_PRINT-3)] + "..."
            name = "\"#{name}\""
        else if name.length > MAX_STRING_LEN_TO_PRINT + 2
            name = ''
        "(#{@type}) #{name} @#{@id}"

    toString: ->
        """
        #{@toShortString()}
        self-size: #{@self_size} bytes
        references:
        #{@references.map((r) -> "    (#{r.type}) #{r.name_or_index}: #{r.toNode?.toShortString() ? 'missing'}").join("\n") }
        referrers:
        #{@referrers.map((r) ->  "    (#{r.type}) #{r.name_or_index}: from #{r.fromNode?.toShortString() ? 'missing'}").join("\n")}
        """

    # Find the given property on this node.  For example,
    #
    #     node.getProperty("__proto__")
    #
    # would return the prototype for this object.  Returns `null` if the property cannot be found.
    getProperty: (name, edgeType='property') ->
        for ref in @references
            if ref.type is edgeType and ref.name is name then return ref.toNode
        return null

class Edge
    constructor: (snapshot, json) ->
        for key, value of json
            if key isnt 'to_node' then this[key] = value

        fillObjectType "edge", this, snapshot.snapshot.meta.edge_types[0]

        if @name_or_index? then @name_or_index = snapshot.strings[@name_or_index]
        # Define @name for convenience
        @name = @name_or_index

        # edge.to_node is always divisible by node_fields.length.  I'm guessing
        # that this is an index into `snapshot.nodes`.
        nodeFields = snapshot.snapshot.meta.node_fields
        @toNodeIndex = json.to_node / nodeFields.length

        # `fromNode` and `toNode` will be filled in by `parseSnapshot`.

    toString: ->
        "#{@name_or_index} (#{@type}) - from #{@fromNode?.toShortString()} to #{@toNode?.toShortString()}"

class HeapSnapshot
    # Create a new HeapSnapshot from a JSON snapshot object.
    constructor: (snapshot, options) ->
        {@nodes, @edges} = parseSnapshot snapshot, options
        @nodesById = ld.indexBy @nodes, 'id'

# Parses a heapsnapshot.
#
# If `options.reporter()` is provided, `reporter({message})` will be called throughout the
# parsing process to indicate progress.
#
exports.parse = (snapshot, options) ->
    if ld.isString snapshot
        snapshot = JSON.parse snapshot
    return new HeapSnapshot(snapshot, options)
