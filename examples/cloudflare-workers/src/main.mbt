///|
/// Example: Minimal Cloudflare Workers setup with httprouter
///
/// This demonstrates how to use the httprouter with Cloudflare Workers.

///|
/// Create a router with sample routes.
fn create_router() -> @lib.Router {
  let router = @lib.Router::new()

  // Simple hello world
  router.get("/", fn(_ctx) {
    @lib.Response::json("{\"message\": \"Hello from MoonBit!\"}")
  })

  // Path parameter example
  router.get("/users/:id", fn(ctx) {
    match ctx.param("id") {
      Some(id) => @lib.Response::json("{\"userId\": \"" + id + "\"}")
      None => @lib.Response::not_found()
    }
  })

  // Echo endpoint
  router.post("/echo", fn(ctx) {
    @lib.Response::json("{\"echo\": \"" + ctx.body + "\"}")
  })

  router
}

///|
/// Global router instance.
let router : @lib.Router = create_router()

///|
/// Handle incoming request from Cloudflare Workers.
/// This function is exported to JavaScript.
pub fn handle_request(
  http_method : String,
  url : String,
  _headers_json : String,
  body : String
) -> String {
  // TODO: Parse headers_json when JSON parsing is available
  let headers : Array[(String, String)] = []

  // Create FetchRequest
  let request = @lib.FetchRequest::new(http_method, url, headers=headers, body=body)

  // Handle request
  let response = router.fetch(request)

  // Return JSON response
  "{\"status\": " + response.status.to_string() +
    ", \"body\": " + escape_json_string(response.body) + "}"
}

///|
/// Escape string for JSON.
fn escape_json_string(s : String) -> String {
  let mut result = "\""
  let chars = s.to_array()
  for c in chars {
    if c == '"' {
      result = result + "\\\""
    } else if c == '\\' {
      result = result + "\\\\"
    } else if c == '\n' {
      result = result + "\\n"
    } else {
      result = result + c.to_string()
    }
  }
  result + "\""
}
