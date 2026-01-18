///|
/// Request context containing all information about the current HTTP request.
/// Designed to be platform-agnostic for future Wasm/Native support.
pub struct Context {
  /// HTTP method of the request
  http_method : Method
  /// Request path (e.g., "/users/123")
  path : String
  /// Path parameters extracted from the URL
  params : Params
  /// Raw query string (e.g., "page=1&limit=10")
  query : String
  /// Request headers as key-value pairs
  headers : Array[(String, String)]
  /// Request body as raw string
  body : String
}

///|
/// Create a new Context with the given request information.
pub fn Context::new(
  http_method : Method,
  path : String,
  query? : String = "",
  headers? : Array[(String, String)] = [],
  body? : String = "",
) -> Context {
  { http_method, path, params: Params::new(), query, headers, body }
}

///|
/// Get a path parameter by name.
pub fn Context::param(self : Context, name : String) -> String? {
  self.params.get(name)
}

///|
/// Get a header value by name (case-insensitive).
pub fn Context::header(self : Context, name : String) -> String? {
  let lower_name = name.to_lower()
  for pair in self.headers {
    if pair.0.to_lower() == lower_name {
      return Some(pair.1)
    }
  }
  None
}

///|
/// HTTP Response representation.
pub struct Response {
  /// HTTP status code
  status : Int
  /// Response headers
  headers : Array[(String, String)]
  /// Response body
  body : String
} derive(Eq, Show)

///|
/// Create a new Response with the given status, headers, and body.
pub fn Response::new(
  status : Int,
  headers? : Array[(String, String)] = [],
  body? : String = "",
) -> Response {
  { status, headers, body }
}

///|
/// Create a plain text response.
pub fn Response::text(body : String, status? : Int = 200) -> Response {
  { status, headers: [("Content-Type", "text/plain; charset=utf-8")], body }
}

///|
/// Create a JSON response.
pub fn Response::json(body : String, status? : Int = 200) -> Response {
  {
    status,
    headers: [("Content-Type", "application/json; charset=utf-8")],
    body,
  }
}

///|
/// Create an HTML response.
pub fn Response::html(body : String, status? : Int = 200) -> Response {
  { status, headers: [("Content-Type", "text/html; charset=utf-8")], body }
}

///|
/// Create a redirect response.
pub fn Response::redirect(location : String, status? : Int = 302) -> Response {
  { status, headers: [("Location", location)], body: "" }
}

///|
/// Create a 404 Not Found response.
pub fn Response::not_found(body? : String = "Not Found") -> Response {
  Response::text(body, status=404)
}

///|
/// Create a 405 Method Not Allowed response.
pub fn Response::method_not_allowed(allowed : Array[Method]) -> Response {
  let allow_header = allowed.map(fn(m) { m.to_string() }).join(", ")
  {
    status: 405,
    headers: [
      ("Content-Type", "text/plain; charset=utf-8"),
      ("Allow", allow_header),
    ],
    body: "Method Not Allowed",
  }
}
