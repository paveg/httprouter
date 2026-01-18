///|
test "Method::from_string parses valid methods" {
  assert_eq!(Method::from_string("GET"), Some(Get))
  assert_eq!(Method::from_string("get"), Some(Get))
  assert_eq!(Method::from_string("POST"), Some(Post))
  assert_eq!(Method::from_string("PUT"), Some(Put))
  assert_eq!(Method::from_string("DELETE"), Some(Delete))
  assert_eq!(Method::from_string("PATCH"), Some(Patch))
}

///|
test "Method::from_string returns None for invalid methods" {
  assert_eq!(Method::from_string("INVALID"), None)
  assert_eq!(Method::from_string(""), None)
}

///|
test "Method::to_string returns correct string" {
  assert_eq!(Get.to_string(), "GET")
  assert_eq!(Post.to_string(), "POST")
  assert_eq!(Delete.to_string(), "DELETE")
}

///|
test "Params::get returns value for existing key" {
  let params = Params::from_array([("id", "123"), ("name", "test")])
  assert_eq!(params.get("id"), Some("123"))
  assert_eq!(params.get("name"), Some("test"))
}

///|
test "Params::get returns None for missing key" {
  let params = Params::from_array([("id", "123")])
  assert_eq!(params.get("missing"), None)
}

///|
test "Params::has checks existence" {
  let params = Params::from_array([("id", "123")])
  assert_true!(params.has("id"))
  assert_false!(params.has("missing"))
}

///|
test "Route matches static path" {
  let route = Route::new(Get, "/users", fn(_ctx) { Response::text("ok") })
  let result = route.match_path("/users")
  assert_true!(result is Some(_))
  assert_eq!(result.unwrap().params.length(), 0)
}

///|
test "Route matches path with parameter" {
  let route = Route::new(Get, "/users/:id", fn(_ctx) { Response::text("ok") })
  let result = route.match_path("/users/123")
  assert_true!(result is Some(_))
  assert_eq!(result.unwrap().params.get("id"), Some("123"))
}

///|
test "Route matches path with multiple parameters" {
  let route = Route::new(
    Get,
    "/users/:userId/posts/:postId",
    fn(_ctx) { Response::text("ok") },
  )
  let result = route.match_path("/users/42/posts/99")
  assert_true!(result is Some(_))
  let params = result.unwrap().params
  assert_eq!(params.get("userId"), Some("42"))
  assert_eq!(params.get("postId"), Some("99"))
}

///|
test "Route matches wildcard path" {
  let route = Route::new(Get, "/files/*path", fn(_ctx) { Response::text("ok") })
  let result = route.match_path("/files/a/b/c.txt")
  assert_true!(result is Some(_))
  assert_eq!(result.unwrap().params.get("path"), Some("a/b/c.txt"))
}

///|
test "Route does not match different path" {
  let route = Route::new(Get, "/users", fn(_ctx) { Response::text("ok") })
  let result = route.match_path("/posts")
  assert_true!(result is None)
}

///|
test "Route does not match shorter path" {
  let route = Route::new(Get, "/users/:id", fn(_ctx) { Response::text("ok") })
  let result = route.match_path("/users")
  assert_true!(result is None)
}

///|
test "Router serves matching route" {
  let router = Router::new()
  router.get("/hello", fn(_ctx) { Response::text("Hello, World!") })
  let ctx = Context::new(Get, "/hello")
  let response = router.serve(ctx)
  assert_eq!(response.status, 200)
  assert_eq!(response.body, "Hello, World!")
}

///|
test "Router returns 404 for unmatched path" {
  let router = Router::new()
  router.get("/hello", fn(_ctx) { Response::text("Hello") })
  let ctx = Context::new(Get, "/notfound")
  let response = router.serve(ctx)
  assert_eq!(response.status, 404)
}

///|
test "Router returns 405 for wrong method" {
  let router = Router::new()
  router.get("/hello", fn(_ctx) { Response::text("Hello") })
  let ctx = Context::new(Post, "/hello")
  let response = router.serve(ctx)
  assert_eq!(response.status, 405)
}

///|
test "Router prioritizes static routes over parameterized" {
  let router = Router::new()
  router.get("/users/:id", fn(_ctx) { Response::text("param") })
  router.get("/users/me", fn(_ctx) { Response::text("static") })
  // Test /users/me matches static route
  let ctx1 = Context::new(Get, "/users/me")
  let response1 = router.serve(ctx1)
  assert_eq!(response1.body, "static")
  // Test /users/123 matches param route
  let ctx2 = Context::new(Get, "/users/123")
  let response2 = router.serve(ctx2)
  assert_eq!(response2.body, "param")
}

///|
test "Router extracts params into context" {
  let router = Router::new()
  router.get(
    "/users/:id",
    fn(ctx) {
      match ctx.param("id") {
        Some(id) => Response::text("User: " + id)
        None => Response::text("No ID")
      }
    },
  )
  let ctx = Context::new(Get, "/users/456")
  let response = router.serve(ctx)
  assert_eq!(response.body, "User: 456")
}

///|
test "Router::from_routes creates router from array" {
  let router = Router::from_routes(
    [
      (Get, "/", fn(_ctx) { Response::text("home") }),
      (Get, "/about", fn(_ctx) { Response::text("about") }),
    ],
  )
  let ctx1 = Context::new(Get, "/")
  assert_eq!(router.serve(ctx1).body, "home")
  let ctx2 = Context::new(Get, "/about")
  assert_eq!(router.serve(ctx2).body, "about")
}

///|
test "Response::json sets correct content type" {
  let response = Response::json("{\"ok\":true}")
  assert_eq!(response.status, 200)
  assert_eq!(response.headers[0].1, "application/json; charset=utf-8")
}

///|
test "Response::redirect sets location header" {
  let response = Response::redirect("/new-location")
  assert_eq!(response.status, 302)
  assert_eq!(response.headers[0], ("Location", "/new-location"))
}

///|
test "Router::fetch handles basic request" {
  let router = Router::new()
  router.get("/hello", fn(_ctx) { Response::text("Hello, World!") })
  let request = FetchRequest::new("GET", "https://example.com/hello")
  let response = router.fetch(request)
  assert_eq!(response.status, 200)
  assert_eq!(response.body, "Hello, World!")
}

///|
test "Router::fetch extracts path parameters" {
  let router = Router::new()
  router.get(
    "/users/:id",
    fn(ctx) {
      match ctx.param("id") {
        Some(id) => Response::text("User: " + id)
        None => Response::text("No ID")
      }
    },
  )
  let request = FetchRequest::new("GET", "https://example.com/users/42")
  let response = router.fetch(request)
  assert_eq!(response.status, 200)
  assert_eq!(response.body, "User: 42")
}

///|
test "Router::fetch handles query string" {
  let router = Router::new()
  router.get(
    "/search",
    fn(ctx) { Response::text("Query: " + ctx.query) },
  )
  let request = FetchRequest::new("GET", "https://example.com/search?q=moonbit")
  let response = router.fetch(request)
  assert_eq!(response.status, 200)
  assert_eq!(response.body, "Query: q=moonbit")
}

///|
test "Router::fetch returns 404 for unmatched path" {
  let router = Router::new()
  router.get("/hello", fn(_ctx) { Response::text("Hello") })
  let request = FetchRequest::new("GET", "https://example.com/notfound")
  let response = router.fetch(request)
  assert_eq!(response.status, 404)
}

///|
test "Router::fetch returns 400 for invalid method" {
  let router = Router::new()
  let request = FetchRequest::new("INVALID", "https://example.com/")
  let response = router.fetch(request)
  assert_eq!(response.status, 400)
}
