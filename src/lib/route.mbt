///|
/// Segment type for path matching.
/// A path is split into segments for matching.
pub enum Segment {
  /// Static segment (e.g., "users")
  Static(String)
  /// Parameter segment (e.g., ":id")
  Param(String)
  /// Wildcard segment (e.g., "*path") - captures rest of path
  Wildcard(String)
  /// Prefix + parameter segment (e.g., "user_:name" -> prefix="user_", name="name")
  PrefixParam(String, String)
} derive(Eq, Show)

///|
/// A registered route with method, path pattern, and handler.
pub struct Route {
  http_method : Method
  path : String
  segments : Array[Segment]
  handler : (Context) -> Response
}

///|
/// Create a new Route.
pub fn Route::new(
  http_method : Method,
  path : String,
  handler : (Context) -> Response,
) -> Route {
  let segments = parse_path(path)
  { http_method, path, segments, handler }
}

///|
/// Parse a path string into segments.
/// Examples:
///   "/" -> []
///   "/users" -> [Static("users")]
///   "/users/:id" -> [Static("users"), Param("id")]
///   "/files/*path" -> [Static("files"), Wildcard("path")]
///   "/user_:name" -> [PrefixParam("user_", "name")]
fn parse_path(path : String) -> Array[Segment] {
  let segments : Array[Segment] = []
  let parts = split_path(path)
  for part in parts {
    if part.length() == 0 {
      continue
    }
    if part[0] == ':' {
      // Parameter segment - skip first character
      let name = extract_name(part, 1)
      segments.push(Param(name))
    } else if part[0] == '*' {
      // Wildcard segment - skip first character
      let name = extract_name(part, 1)
      segments.push(Wildcard(name))
    } else {
      // Check for prefix:param pattern (e.g., "user_:name")
      match find_colon_index(part) {
        Some(colon_idx) => {
          let prefix = extract_name(part, 0).to_array()[:colon_idx]
            .iter()
            .fold(init="", fn(acc, c) { acc + c.to_string() })
          let name = extract_name(part, colon_idx + 1)
          segments.push(PrefixParam(prefix, name))
        }
        None => segments.push(Static(part))
      }
    }
  }
  segments
}

///|
/// Find the index of ':' in a string (for prefix:param detection).
fn find_colon_index(s : String) -> Int? {
  for i = 0; i < s.length(); i = i + 1 {
    if s[i].to_int() == ':'.to_int() {
      return Some(i)
    }
  }
  None
}

///|
/// Check if a string starts with a prefix.
fn starts_with(s : String, prefix : String) -> Bool {
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
/// Extract name from a string starting at given index.
fn extract_name(s : String, start : Int) -> String {
  let result = StringBuilder::new()
  for i = start; i < s.length(); i = i + 1 {
    result.write_char(s[i].to_int().unsafe_to_char())
  }
  result.to_string()
}

///|
/// Split a path by '/' into parts.
fn split_path(path : String) -> Array[String] {
  let parts : Array[String] = []
  let current = StringBuilder::new()
  for char in path {
    if char == '/' {
      if current.to_string().length() > 0 {
        parts.push(current.to_string())
        current.reset()
      }
    } else {
      current.write_char(char)
    }
  }
  if current.to_string().length() > 0 {
    parts.push(current.to_string())
  }
  parts
}

///|
/// Match result containing extracted parameters.
pub struct MatchResult {
  params : Params
  matched : Bool
} derive(Eq, Show)

///|
/// Try to match a request path against this route's pattern.
/// Returns extracted parameters if matched, None otherwise.
pub fn Route::match_path(self : Route, request_path : String) -> MatchResult? {
  let request_parts = split_path(request_path)
  let params = Params::new()
  let mut req_idx = 0
  for segment in self.segments {
    match segment {
      Static(s) => {
        if req_idx >= request_parts.length() {
          return None
        }
        if request_parts[req_idx] != s {
          return None
        }
        req_idx = req_idx + 1
      }
      Param(name) => {
        if req_idx >= request_parts.length() {
          return None
        }
        params.add(name, request_parts[req_idx])
        req_idx = req_idx + 1
      }
      Wildcard(name) => {
        // Wildcard captures the rest of the path
        if req_idx >= request_parts.length() {
          // Wildcard can match empty string
          params.add(name, "")
        } else {
          let rest = join_parts(request_parts, req_idx)
          params.add(name, rest)
        }
        // Wildcard must be last segment
        return Some({ params, matched: true })
      }
      PrefixParam(prefix, name) => {
        if req_idx >= request_parts.length() {
          return None
        }
        let part = request_parts[req_idx]
        // Check if part starts with prefix
        if not(starts_with(part, prefix)) {
          return None
        }
        // Extract the value after the prefix
        let value = extract_name(part, prefix.length())
        params.add(name, value)
        req_idx = req_idx + 1
      }
    }
  }
  // All segments matched, check if request path is fully consumed
  if req_idx == request_parts.length() {
    Some({ params, matched: true })
  } else {
    None
  }
}

///|
/// Join array parts from index with "/".
fn join_parts(parts : Array[String], from_idx : Int) -> String {
  let result = StringBuilder::new()
  for i = from_idx; i < parts.length(); i = i + 1 {
    if i > from_idx {
      result.write_char('/')
    }
    result.write_string(parts[i])
  }
  result.to_string()
}

///|
/// Check if this route has only static segments.
/// Static routes have higher priority in matching.
pub fn Route::is_static(self : Route) -> Bool {
  for segment in self.segments {
    match segment {
      Param(_) | Wildcard(_) | PrefixParam(_, _) => return false
      Static(_) => continue
    }
  }
  true
}

///|
/// Get the number of static segments (for priority sorting).
pub fn Route::static_count(self : Route) -> Int {
  let mut count = 0
  for segment in self.segments {
    match segment {
      Static(_) => count = count + 1
      _ => ()
    }
  }
  count
}
