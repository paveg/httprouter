///|
/// Platform adapter interfaces for running the router on various backends.
/// Currently supports: Cloudflare Workers, generic Wasm environments.

///|
/// Fetch-style request representation.
/// Maps to Web Fetch API Request used by Cloudflare Workers, Deno, etc.
pub struct FetchRequest {
  /// HTTP method (GET, POST, etc.)
  method : String
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
  method : String,
  url : String,
  headers~ : Array[(String, String)] = [],
  body~ : String = ""
) -> FetchRequest {
  { method, url, headers, body }
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
  headers~ : Array[(String, String)] = [],
  body~ : String = ""
) -> FetchResponse {
  { status, headers, body }
}

///|
/// Convert internal Response to FetchResponse.
pub fn Response::to_fetch_response(self : Response) -> FetchResponse {
  { status: self.status, headers: self.headers, body: self.body }
}

///|
/// Parse URL to extract path and query string.
/// Example: "https://example.com/users/123?page=1" -> ("/users/123", "page=1")
fn parse_url(url : String) -> (String, String) {
  // Find the path start (after ://)
  let path_start = match url.index_of("://") {
    Some(idx) => {
      // Find the first / after the host
      let after_protocol = idx + 3
      match url.char_at(after_protocol) {
        // Skip until we find /
        _ => {
          let mut i = after_protocol
          while i < url.length() && url.char_at(i) != Some('/') {
            i = i + 1
          }
          i
        }
      }
    }
    None => 0 // No protocol, assume path starts at beginning
  }
  // Extract path and query
  let path_and_query = if path_start < url.length() {
    url.substring(start=path_start)
  } else {
    "/"
  }
  // Split by ?
  match path_and_query.index_of("?") {
    Some(idx) => (
      path_and_query.substring(end=idx),
      path_and_query.substring(start=idx + 1),
    )
    None => (path_and_query, "")
  }
}

///|
/// Handle a FetchRequest using the router and return a FetchResponse.
/// This is the main entry point for Cloudflare Workers and similar platforms.
pub fn Router::fetch(self : Router, request : FetchRequest) -> FetchResponse {
  // Parse method
  let http_method = match Method::from_string(request.method) {
    Some(m) => m
    None => {
      // Invalid method, return 400
      return {
        status: 400,
        headers: [("Content-Type", "text/plain; charset=utf-8")],
        body: "Bad Request: Invalid HTTP method",
      }
    }
  }
  // Parse URL
  let (path, query) = parse_url(request.url)
  // Create context
  let ctx = Context::new(
    http_method,
    path,
    query=query,
    headers=request.headers,
    body=request.body,
  )
  // Serve and convert response
  let response = self.serve(ctx)
  response.to_fetch_response()
}
