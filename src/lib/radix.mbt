///|
/// Radix tree implementation for efficient route matching.
/// Provides O(k) lookup where k is the path depth, compared to O(n) linear search.

///|
/// Node kind in the radix tree.
/// Priority order: Static > PrefixParam > Param > Wildcard
pub enum NodeKind {
  /// Static path segment (e.g., "users", "api")
  Static(String)
  /// Parameter segment (e.g., ":id" -> Param("id"))
  Param(String)
  /// Wildcard segment (e.g., "*path" -> Wildcard("path"))
  Wildcard(String)
  /// Prefix + parameter segment (e.g., "user_:name" -> prefix="user_", name="name")
  PrefixParam(String, String)
} derive(Eq, Show)

///|
/// Get the priority of a node kind.
/// Lower value = higher priority.
fn NodeKind::priority(self : NodeKind) -> Int {
  match self {
    Static(_) => 0
    PrefixParam(_, _) => 1
    Param(_) => 2
    Wildcard(_) => 3
  }
}

///|
/// Radix tree node.
pub struct Node {
  /// The kind of this node
  kind : NodeKind
  /// Child nodes, sorted by priority
  mut children : Array[Node]
  /// Handlers registered at this node, keyed by HTTP method
  handlers : Array[(Method, (Context) -> Response)]
}

///|
/// Create a new node with the given kind.
fn Node::new(kind : NodeKind) -> Node {
  { kind, children: [], handlers: [] }
}

///|
/// Create a root node.
fn Node::root() -> Node {
  Node::new(Static(""))
}

///|
/// Add a handler for a method at this node.
fn Node::add_handler(
  self : Node,
  http_method : Method,
  handler : (Context) -> Response,
) -> Unit {
  // Check if method already exists
  for i = 0; i < self.handlers.length(); i = i + 1 {
    if self.handlers[i].0 == http_method {
      // Replace existing handler
      self.handlers[i] = (http_method, handler)
      return
    }
  }
  // Add new handler
  self.handlers.push((http_method, handler))
}

///|
/// Get a handler for a method at this node.
fn Node::get_handler(
  self : Node,
  http_method : Method,
) -> ((Context) -> Response)? {
  for pair in self.handlers {
    if pair.0 == http_method {
      return Some(pair.1)
    }
  }
  None
}

///|
/// Get all methods registered at this node.
fn Node::get_methods(self : Node) -> Array[Method] {
  let methods : Array[Method] = []
  for pair in self.handlers {
    methods.push(pair.0)
  }
  methods
}

///|
/// Find a child node matching the given kind.
fn Node::find_child(self : Node, kind : NodeKind) -> Node? {
  for child in self.children {
    if child.kind == kind {
      return Some(child)
    }
  }
  None
}

///|
/// Add a child node, maintaining priority order.
fn Node::add_child(self : Node, child : Node) -> Unit {
  // Insert in priority order (lower priority value = higher priority = earlier in array)
  let priority = child.kind.priority()
  let new_children : Array[Node] = []
  let mut inserted = false
  for existing in self.children {
    if not(inserted) && priority < existing.kind.priority() {
      new_children.push(child)
      inserted = true
    }
    new_children.push(existing)
  }
  if not(inserted) {
    new_children.push(child)
  }
  self.children = new_children
}

///|
/// Radix tree for route matching.
pub struct RadixTree {
  /// Root node of the tree
  root : Node
}

///|
/// Create a new empty radix tree.
pub fn RadixTree::new() -> RadixTree {
  { root: Node::root() }
}

///|
/// Internal lookup result for radix tree.
priv struct RadixLookup {
  /// The matched handler
  handler : (Context) -> Response
  /// Extracted path parameters
  params : Params
}

///|
/// Insert a route into the radix tree.
pub fn RadixTree::insert(
  self : RadixTree,
  http_method : Method,
  path : String,
  handler : (Context) -> Response,
) -> Unit {
  let segments = parse_path(path)

  // Traverse/create nodes for each segment
  let mut current = self.root
  for segment in segments {
    let kind = segment_to_node_kind(segment)
    match current.find_child(kind) {
      Some(child) => current = child
      None => {
        let new_node = Node::new(kind)
        current.add_child(new_node)
        // Find the just-added child
        match current.find_child(kind) {
          Some(child) => current = child
          None => abort("Failed to find just-added child")
        }
      }
    }
  }

  // Register handler at the final node
  current.add_handler(http_method, handler)
}

///|
/// Convert a Segment to a NodeKind.
fn segment_to_node_kind(segment : Segment) -> NodeKind {
  match segment {
    Static(s) => NodeKind::Static(s)
    Param(name) => NodeKind::Param(name)
    Wildcard(name) => NodeKind::Wildcard(name)
    PrefixParam(prefix, name) => NodeKind::PrefixParam(prefix, name)
  }
}

///|
/// Look up a route in the radix tree.
/// Returns the handler and extracted parameters if found.
fn RadixTree::lookup_internal(
  self : RadixTree,
  http_method : Method,
  path : String,
) -> RadixLookup? {
  let segments = path_to_segments(path)
  let params = Params::new()
  match self.lookup_node(self.root, segments, 0, params) {
    Some(node) =>
      match node.get_handler(http_method) {
        Some(handler) => Some({ handler, params })
        None => None
      }
    None => None
  }
}

///|
/// Split path into raw string segments.
fn path_to_segments(path : String) -> Array[String] {
  let result : Array[String] = []
  let chars = path.to_array()
  let mut current = ""
  let mut i = 0

  // Skip leading slash
  if chars.length() > 0 && chars[0] == '/' {
    i = 1
  }
  while i < chars.length() {
    if chars[i] == '/' {
      if current.length() > 0 {
        result.push(current)
        current = ""
      }
    } else {
      current = current + chars[i].to_string()
    }
    i = i + 1
  }
  if current.length() > 0 {
    result.push(current)
  }
  result
}

///|
/// Recursively look up a node in the tree.
fn RadixTree::lookup_node(
  self : RadixTree,
  node : Node,
  segments : Array[String],
  index : Int,
  params : Params,
) -> Node? {
  // Base case: consumed all segments
  if index >= segments.length() {
    // Check if this node has handlers
    if node.handlers.length() > 0 {
      return Some(node)
    }
    // Also check for wildcard children that can match empty string
    for child in node.children {
      match child.kind {
        Wildcard(name) =>
          if child.handlers.length() > 0 {
            params.set(name, "")
            return Some(child)
          }
        _ => ()
      }
    }
    return None
  }
  let segment = segments[index]

  // Try children in priority order (static first, then param, then wildcard)
  for child in node.children {
    match child.kind {
      Static(s) =>
        if s == segment {
          match self.lookup_node(child, segments, index + 1, params) {
            Some(result) => return Some(result)
            None => ()
          }
        }
      Param(name) => {
        // Param matches any single segment
        params.set(name, segment)
        match self.lookup_node(child, segments, index + 1, params) {
          Some(result) => return Some(result)
          None =>
            // Backtrack: remove the param
            params.remove(name)
        }
      }
      Wildcard(name) => {
        // Wildcard matches all remaining segments
        let remaining = collect_remaining(segments, index)
        params.set(name, remaining)
        if child.handlers.length() > 0 {
          return Some(child)
        }
        // Backtrack
        params.remove(name)
      }
      PrefixParam(prefix, name) =>
        // Check if segment starts with prefix
        if has_prefix(segment, prefix) {
          // Extract value after prefix
          let value = extract_after_prefix(segment, prefix.length())
          params.set(name, value)
          match self.lookup_node(child, segments, index + 1, params) {
            Some(result) => return Some(result)
            None => params.remove(name)
          }
        }
    }
  }
  None
}

///|
/// Check if a string has a prefix.
fn has_prefix(s : String, prefix : String) -> Bool {
  if prefix.length() > s.length() {
    return false
  }
  for i = 0; i < prefix.length(); i = i + 1 {
    if s[i].to_int() != prefix[i].to_int() {
      return false
    }
  }
  true
}

///|
/// Extract substring after a prefix.
fn extract_after_prefix(s : String, prefix_len : Int) -> String {
  if prefix_len >= s.length() {
    return ""
  }
  s.to_array()[prefix_len:]
  .iter()
  .fold(init="", fn(acc, c) { acc + c.to_string() })
}

///|
/// Collect remaining segments into a path string.
fn collect_remaining(segments : Array[String], from_index : Int) -> String {
  let mut result = ""
  for i = from_index; i < segments.length(); i = i + 1 {
    if i > from_index {
      result = result + "/"
    }
    result = result + segments[i]
  }
  result
}

///|
/// Find a node matching the path (without method check).
/// Used to collect allowed methods for 405 responses.
fn RadixTree::find_node(self : RadixTree, path : String) -> Node? {
  let segments = path_to_segments(path)
  let params = Params::new()
  self.lookup_node(self.root, segments, 0, params)
}

///|
/// Radix tree lookup result for router integration.
pub enum RadixResult {
  /// Found a matching route with handler
  Found((Context) -> Response, Params)
  /// Path matches but method doesn't (405)
  MethodNotAllowed(Array[Method])
  /// No matching path (404)
  NotFound
}

///|
/// Look up a route in the radix tree with 405 support.
pub fn RadixTree::lookup(
  self : RadixTree,
  http_method : Method,
  path : String,
) -> RadixResult {
  match self.lookup_internal(http_method, path) {
    Some(result) => Found(result.handler, result.params)
    None =>
      // Check if path exists but method doesn't match
      match self.find_node(path) {
        Some(node) => {
          let methods = node.get_methods()
          if methods.length() > 0 {
            MethodNotAllowed(methods)
          } else {
            NotFound
          }
        }
        None => NotFound
      }
  }
}
