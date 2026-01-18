///|
/// HTTP Router with linear matching.
/// Routes are matched in priority order:
/// 1. Static routes (no parameters) first
/// 2. Routes with more static segments preferred
/// 3. Registration order as tiebreaker
pub struct Router {
  routes : Array[Route]
  /// Custom 404 handler
  mut not_found_handler : ((Context) -> Response)?
  /// Custom 405 handler
  mut method_not_allowed_handler : ((Array[Method]) -> Response)?
  /// Global middleware (before handlers)
  middleware : Array[(Context) -> Context?]
}

///|
/// Create a new Router.
pub fn Router::new() -> Router {
  {
    routes: [],
    not_found_handler: None,
    method_not_allowed_handler: None,
    middleware: [],
  }
}

///|
/// Register a route with the given method, path, and handler.
pub fn Router::handle(
  self : Router,
  http_method : Method,
  path : String,
  handler : (Context) -> Response
) -> Unit {
  let route = Route::new(http_method, path, handler)
  self.routes.push(route)
  // Sort routes by priority: static first, then by static segment count
  self.routes.sort_by(fn(a, b) {
    // Static routes come first
    let a_static = a.is_static()
    let b_static = b.is_static()
    if a_static && not(b_static) {
      return -1
    }
    if not(a_static) && b_static {
      return 1
    }
    // More static segments = higher priority
    let a_count = a.static_count()
    let b_count = b.static_count()
    b_count - a_count
  })
}

///|
/// Register a GET route.
pub fn Router::get(
  self : Router,
  path : String,
  handler : (Context) -> Response
) -> Unit {
  self.handle(Get, path, handler)
}

///|
/// Register a POST route.
pub fn Router::post(
  self : Router,
  path : String,
  handler : (Context) -> Response
) -> Unit {
  self.handle(Post, path, handler)
}

///|
/// Register a PUT route.
pub fn Router::put(
  self : Router,
  path : String,
  handler : (Context) -> Response
) -> Unit {
  self.handle(Put, path, handler)
}

///|
/// Register a DELETE route.
pub fn Router::delete(
  self : Router,
  path : String,
  handler : (Context) -> Response
) -> Unit {
  self.handle(Delete, path, handler)
}

///|
/// Register a PATCH route.
pub fn Router::patch(
  self : Router,
  path : String,
  handler : (Context) -> Response
) -> Unit {
  self.handle(Patch, path, handler)
}

///|
/// Register a HEAD route.
pub fn Router::head(
  self : Router,
  path : String,
  handler : (Context) -> Response
) -> Unit {
  self.handle(Head, path, handler)
}

///|
/// Register an OPTIONS route.
pub fn Router::options(
  self : Router,
  path : String,
  handler : (Context) -> Response
) -> Unit {
  self.handle(Options, path, handler)
}

///|
/// Set a custom 404 Not Found handler.
pub fn Router::set_not_found(
  self : Router,
  handler : (Context) -> Response
) -> Unit {
  self.not_found_handler = Some(handler)
}

///|
/// Set a custom 405 Method Not Allowed handler.
pub fn Router::set_method_not_allowed(
  self : Router,
  handler : (Array[Method]) -> Response
) -> Unit {
  self.method_not_allowed_handler = Some(handler)
}

///|
/// Add a global middleware.
/// Middleware runs before the route handler.
/// Return None to short-circuit the request.
pub fn Router::add_middleware(
  self : Router,
  mw : (Context) -> Context?
) -> Unit {
  self.middleware.push(mw)
}

///|
/// Route lookup result.
priv enum LookupResult {
  /// Found a matching route
  Found(Route, Params)
  /// Path matches but method doesn't (405)
  MethodNotAllowed(Array[Method])
  /// No matching path (404)
  NotFound
}

///|
/// Look up a route for the given method and path.
fn Router::lookup(
  self : Router,
  http_method : Method,
  path : String
) -> LookupResult {
  let allowed_methods : Array[Method] = []
  for route in self.routes {
    match route.match_path(path) {
      Some(result) => {
        if route.http_method == http_method {
          return Found(route, result.params)
        }
        // Path matches but method doesn't - collect allowed methods
        if not(allowed_methods.contains(route.http_method)) {
          allowed_methods.push(route.http_method)
        }
      }
      None => continue
    }
  }
  if allowed_methods.length() > 0 {
    MethodNotAllowed(allowed_methods)
  } else {
    NotFound
  }
}

///|
/// Handle an incoming request and return a response.
pub fn Router::serve(self : Router, ctx : Context) -> Response {
  // Run middleware
  let mut current_ctx = ctx
  for mw in self.middleware {
    match mw(current_ctx) {
      Some(new_ctx) => current_ctx = new_ctx
      None => {
        // Middleware short-circuited, return early
        return Response::text("Forbidden", status=403)
      }
    }
  }
  // Look up route
  match self.lookup(current_ctx.http_method, current_ctx.path) {
    Found(route, params) => {
      // Create new context with params
      let ctx_with_params : Context = {
        http_method: current_ctx.http_method,
        path: current_ctx.path,
        params,
        query: current_ctx.query,
        headers: current_ctx.headers,
        body: current_ctx.body,
      }
      (route.handler)(ctx_with_params)
    }
    MethodNotAllowed(allowed) =>
      match self.method_not_allowed_handler {
        Some(handler) => handler(allowed)
        None => Response::method_not_allowed(allowed)
      }
    NotFound =>
      match self.not_found_handler {
        Some(handler) => handler(current_ctx)
        None => Response::not_found()
      }
  }
}

///|
/// Create a router from an array of route definitions.
/// Useful for declarative route configuration.
pub fn Router::from_routes(
  routes : Array[(Method, String, (Context) -> Response)]
) -> Router {
  let router = Router::new()
  for tuple in routes {
    router.handle(tuple.0, tuple.1, tuple.2)
  }
  router
}
