///|
/// Platform adapter interfaces for running the router on various backends.
/// Currently supports: Cloudflare Workers, generic Wasm environments.

///|
/// Fetch-style request representation.
/// Maps to Web Fetch API Request used by Cloudflare Workers, Deno, etc.
pub struct FetchRequest {
  /// HTTP method (GET, POST, etc.)
  http_method : String
  /// Full URL (e.g., "https://example.com/users/123?page=1")
  url : String
  /// Request headers as key-value pairs
  headers : Array[(String, String)]
  /// Request body as raw string
  body : String
}

///|
/// Create a new FetchRequest.
pub fn FetchRequest::new(
  http_method : String,
  url : String,
  headers? : Array[(String, String)] = [],
  body? : String = "",
) -> FetchRequest {
  { http_method, url, headers, body }
}

///|
/// Fetch-style response representation.
/// Maps to Web Fetch API Response.
pub struct FetchResponse {
  /// HTTP status code
  status : Int
  /// Response headers
  headers : Array[(String, String)]
  /// Response body
  body : String
}

///|
/// Create a new FetchResponse.
pub fn FetchResponse::new(
  status : Int,
  headers? : Array[(String, String)] = [],
  body? : String = "",
) -> FetchResponse {
  { status, headers, body }
}

///|
/// Convert internal Response to FetchResponse.
pub fn Response::to_fetch_response(self : Response) -> FetchResponse {
  { status: self.status, headers: self.headers, body: self.body }
}

///|
/// Find index of a character in a string.
fn find_char(s : String, c : Char) -> Int? {
  let code = c.to_int()
  for i = 0; i < s.length(); i = i + 1 {
    if s[i].to_int() == code {
      return Some(i)
    }
  }
  None
}

///|
/// Find index of a substring in a string.
fn find_substring(s : String, pattern : String) -> Int? {
  if pattern.length() == 0 {
    return Some(0)
  }
  if pattern.length() > s.length() {
    return None
  }
  for i = 0; i <= s.length() - pattern.length(); i = i + 1 {
    let mut matched = true
    for j = 0; j < pattern.length(); j = j + 1 {
      if s[i + j].to_int() != pattern[j].to_int() {
        matched = false
        break
      }
    }
    if matched {
      return Some(i)
    }
  }
  None
}

///|
/// Parse URL to extract path and query string.
/// Example: "https://example.com/users/123?page=1" -> ("/users/123", "page=1")
fn parse_url(url : String) -> (String, String) {
  // Find the path start (after ://)
  let path_start = match find_substring(url, "://") {
    Some(idx) => {
      // Find the first / after the host
      let after_protocol = idx + 3
      let mut i = after_protocol
      let slash_code = '/'.to_int()
      while i < url.length() && url[i].to_int() != slash_code {
        i = i + 1
      }
      i
    }
    None => 0 // No protocol, assume path starts at beginning
  }
  // Extract path and query
  let path_and_query : String = if path_start < url.length() {
    url.to_array()[path_start:]
    .iter()
    .fold(init="", fn(acc, c) { acc + c.to_string() })
  } else {
    "/"
  }
  // Split by ?
  match find_char(path_and_query, '?') {
    Some(idx) => {
      let chars = path_and_query.to_array()
      let path = chars[:idx]
        .iter()
        .fold(init="", fn(acc, c) { acc + c.to_string() })
      let query = chars[idx + 1:]
        .iter()
        .fold(init="", fn(acc, c) { acc + c.to_string() })
      (path, query)
    }
    None => (path_and_query, "")
  }
}

///|
/// Handle a FetchRequest using the router and return a FetchResponse.
/// This is the main entry point for Cloudflare Workers and similar platforms.
pub fn Router::fetch(self : Router, request : FetchRequest) -> FetchResponse {
  // Parse method
  let http_method = match Method::from_string(request.http_method) {
    Some(m) => m
    None =>
      // Invalid method, return 400
      return {
        status: 400,
        headers: [("Content-Type", "text/plain; charset=utf-8")],
        body: "Bad Request: Invalid HTTP method",
      }
  }
  // Parse URL
  let (path, query) = parse_url(request.url)
  // Create context
  let ctx = Context::new(
    http_method,
    path,
    query~,
    headers=request.headers,
    body=request.body,
  )
  // Serve and convert response
  let response = self.serve(ctx)
  response.to_fetch_response()
}
