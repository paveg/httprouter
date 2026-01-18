///|
/// HTTP methods supported by the router.
/// Based on RFC 7231 and RFC 5789.
pub enum Method {
  Get
  Post
  Put
  Delete
  Patch
  Head
  Options
  Connect
  Trace
} derive(Eq, Show)

///|
/// Parse a string into an HTTP method.
/// Returns None if the string is not a valid HTTP method.
pub fn Method::from_string(s : String) -> Method? {
  match s.to_upper() {
    "GET" => Some(Get)
    "POST" => Some(Post)
    "PUT" => Some(Put)
    "DELETE" => Some(Delete)
    "PATCH" => Some(Patch)
    "HEAD" => Some(Head)
    "OPTIONS" => Some(Options)
    "CONNECT" => Some(Connect)
    "TRACE" => Some(Trace)
    _ => None
  }
}

///|
/// Convert an HTTP method to its string representation.
pub fn Method::to_string(self : Method) -> String {
  match self {
    Get => "GET"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Patch => "PATCH"
    Head => "HEAD"
    Options => "OPTIONS"
    Connect => "CONNECT"
    Trace => "TRACE"
  }
}
