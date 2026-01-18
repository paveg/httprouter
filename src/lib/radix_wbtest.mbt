///|
/// Radix tree specific tests

///|
test "RadixTree static route priority regardless of registration order" {
  // Register param route first, then static route
  let router = Router::new()
  router.get("/api/:version", fn(_ctx) { Response::text("param") })
  router.get("/api/v1", fn(_ctx) { Response::text("static") })

  // /api/v1 should match static route
  let ctx1 = Context::new(Get, "/api/v1")
  assert_eq(router.serve(ctx1).body, "static")

  // /api/v2 should match param route
  let ctx2 = Context::new(Get, "/api/v2")
  assert_eq(router.serve(ctx2).body, "param")
}

///|
test "RadixTree multiple methods on same path" {
  let router = Router::new()
  router.get("/resource", fn(_ctx) { Response::text("GET") })
  router.post("/resource", fn(_ctx) { Response::text("POST") })
  router.put("/resource", fn(_ctx) { Response::text("PUT") })
  router.delete("/resource", fn(_ctx) { Response::text("DELETE") })
  assert_eq(router.serve(Context::new(Get, "/resource")).body, "GET")
  assert_eq(router.serve(Context::new(Post, "/resource")).body, "POST")
  assert_eq(router.serve(Context::new(Put, "/resource")).body, "PUT")
  assert_eq(router.serve(Context::new(Delete, "/resource")).body, "DELETE")
}

///|
test "RadixTree param priority over wildcard" {
  let router = Router::new()
  router.get("/files/*path", fn(_ctx) { Response::text("wildcard") })
  router.get("/files/:name", fn(_ctx) { Response::text("param") })

  // Single segment should match param (higher priority)
  let ctx1 = Context::new(Get, "/files/readme.txt")
  assert_eq(router.serve(ctx1).body, "param")

  // Multiple segments should match wildcard
  let ctx2 = Context::new(Get, "/files/docs/api/readme.txt")
  assert_eq(router.serve(ctx2).body, "wildcard")
}

///|
test "RadixTree deeply nested routes" {
  let router = Router::new()
  router.get("/a/b/c/d/e", fn(_ctx) { Response::text("deep") })
  router.get("/a/b/:c/d/:e", fn(ctx) {
    let c = ctx.param("c").unwrap_or("?")
    let e = ctx.param("e").unwrap_or("?")
    Response::text("params: " + c + ", " + e)
  })

  // Exact match
  let ctx1 = Context::new(Get, "/a/b/c/d/e")
  assert_eq(router.serve(ctx1).body, "deep")

  // Param match
  let ctx2 = Context::new(Get, "/a/b/x/d/y")
  assert_eq(router.serve(ctx2).body, "params: x, y")
}

///|
test "RadixTree 405 returns allowed methods" {
  let router = Router::new()
  router.get("/api", fn(_ctx) { Response::text("GET") })
  router.post("/api", fn(_ctx) { Response::text("POST") })

  // PATCH on /api should return 405
  let ctx = Context::new(Patch, "/api")
  let response = router.serve(ctx)
  assert_eq(response.status, 405)
  // Check Allow header contains GET and POST
  let mut has_allow = false
  for header in response.headers {
    if header.0 == "Allow" {
      has_allow = true
      assert_true(header.1.contains("GET"))
      assert_true(header.1.contains("POST"))
    }
  }
  assert_true(has_allow)
}

///|
test "RadixTree wildcard captures all remaining segments" {
  let router = Router::new()
  router.get("/static/*filepath", fn(ctx) {
    Response::text(ctx.param("filepath").unwrap_or("none"))
  })

  // Single segment
  let ctx1 = Context::new(Get, "/static/style.css")
  assert_eq(router.serve(ctx1).body, "style.css")

  // Multiple segments
  let ctx2 = Context::new(Get, "/static/js/app/main.js")
  assert_eq(router.serve(ctx2).body, "js/app/main.js")
}

///|
test "RadixTree root path" {
  let router = Router::new()
  router.get("/", fn(_ctx) { Response::text("root") })
  router.get("/api", fn(_ctx) { Response::text("api") })
  let ctx1 = Context::new(Get, "/")
  assert_eq(router.serve(ctx1).body, "root")
  let ctx2 = Context::new(Get, "/api")
  assert_eq(router.serve(ctx2).body, "api")
}

///|
test "RadixTree shared prefix routes" {
  let router = Router::new()
  router.get("/users", fn(_ctx) { Response::text("users list") })
  router.get("/users/:id", fn(_ctx) { Response::text("user detail") })
  router.get("/users/:id/posts", fn(_ctx) { Response::text("user posts") })
  router.get("/users/:id/posts/:pid", fn(_ctx) { Response::text("post detail") })
  assert_eq(router.serve(Context::new(Get, "/users")).body, "users list")
  assert_eq(router.serve(Context::new(Get, "/users/42")).body, "user detail")
  assert_eq(
    router.serve(Context::new(Get, "/users/42/posts")).body,
    "user posts",
  )
  assert_eq(
    router.serve(Context::new(Get, "/users/42/posts/99")).body,
    "post detail",
  )
}

///|
test "httprouter: static routes with common prefix" {
  // Based on TestTreeAddAndGet
  let router = Router::new()
  router.get("/hi", fn(_ctx) { Response::text("hi") })
  router.get("/contact", fn(_ctx) { Response::text("contact") })
  router.get("/co", fn(_ctx) { Response::text("co") })
  router.get("/c", fn(_ctx) { Response::text("c") })
  router.get("/a", fn(_ctx) { Response::text("a") })
  router.get("/ab", fn(_ctx) { Response::text("ab") })
  router.get("/doc/", fn(_ctx) { Response::text("doc/") })
  router.get("/doc/go_faq.html", fn(_ctx) { Response::text("doc/go_faq.html") })
  router.get("/doc/go1.html", fn(_ctx) { Response::text("doc/go1.html") })
  assert_eq(router.serve(Context::new(Get, "/hi")).body, "hi")
  assert_eq(router.serve(Context::new(Get, "/contact")).body, "contact")
  assert_eq(router.serve(Context::new(Get, "/co")).body, "co")
  assert_eq(router.serve(Context::new(Get, "/c")).body, "c")
  assert_eq(router.serve(Context::new(Get, "/a")).body, "a")
  assert_eq(router.serve(Context::new(Get, "/ab")).body, "ab")
  assert_eq(router.serve(Context::new(Get, "/doc/")).body, "doc/")
  assert_eq(
    router.serve(Context::new(Get, "/doc/go_faq.html")).body,
    "doc/go_faq.html",
  )
  assert_eq(
    router.serve(Context::new(Get, "/doc/go1.html")).body,
    "doc/go1.html",
  )
}

///|
test "httprouter: param routes" {
  // Based on TestTreeWildcard
  let router = Router::new()
  router.get("/cmd/:tool/:sub", fn(ctx) {
    let tool = ctx.param("tool").unwrap_or("?")
    let sub = ctx.param("sub").unwrap_or("?")
    Response::text("tool=" + tool + ",sub=" + sub)
  })
  router.get("/search/:query", fn(ctx) {
    Response::text("query=" + ctx.param("query").unwrap_or("?"))
  })
  // Prefix + param pattern (e.g., "user_:name")
  router.get("/user_:name", fn(ctx) {
    Response::text("name=" + ctx.param("name").unwrap_or("?"))
  })
  assert_eq(
    router.serve(Context::new(Get, "/cmd/test/3")).body,
    "tool=test,sub=3",
  )
  assert_eq(
    router.serve(Context::new(Get, "/search/moonbit")).body,
    "query=moonbit",
  )
  assert_eq(router.serve(Context::new(Get, "/user_gopher")).body, "name=gopher")
}

///|
test "httprouter: catch-all wildcard" {
  // Based on TestTreeCatchAll
  let router = Router::new()
  router.get("/src/*filepath", fn(ctx) {
    Response::text("filepath=" + ctx.param("filepath").unwrap_or("?"))
  })
  router.get("/files/*path", fn(ctx) {
    Response::text("path=" + ctx.param("path").unwrap_or("?"))
  })
  assert_eq(
    router.serve(Context::new(Get, "/src/some/file.png")).body,
    "filepath=some/file.png",
  )
  assert_eq(router.serve(Context::new(Get, "/src/")).body, "filepath=")
  assert_eq(
    router.serve(Context::new(Get, "/files/css/style.css")).body,
    "path=css/style.css",
  )
}

///|
test "httprouter: mixed static and param routes" {
  // Based on TestRouterAPI
  let router = Router::new()
  router.get("/user/:name", fn(ctx) {
    Response::text("name=" + ctx.param("name").unwrap_or("?"))
  })
  router.get("/user/:name/profile", fn(ctx) {
    Response::text("profile:" + ctx.param("name").unwrap_or("?"))
  })
  router.get("/user/special", fn(_ctx) { Response::text("special") })

  // Static should match before param
  assert_eq(router.serve(Context::new(Get, "/user/special")).body, "special")
  assert_eq(router.serve(Context::new(Get, "/user/gopher")).body, "name=gopher")
  assert_eq(
    router.serve(Context::new(Get, "/user/gopher/profile")).body,
    "profile:gopher",
  )
}

///|
test "httprouter: all HTTP methods" {
  let router = Router::new()
  router.get("/", fn(_ctx) { Response::text("GET") })
  router.post("/", fn(_ctx) { Response::text("POST") })
  router.put("/", fn(_ctx) { Response::text("PUT") })
  router.delete("/", fn(_ctx) { Response::text("DELETE") })
  router.patch("/", fn(_ctx) { Response::text("PATCH") })
  router.head("/", fn(_ctx) { Response::text("HEAD") })
  router.options("/", fn(_ctx) { Response::text("OPTIONS") })
  assert_eq(router.serve(Context::new(Get, "/")).body, "GET")
  assert_eq(router.serve(Context::new(Post, "/")).body, "POST")
  assert_eq(router.serve(Context::new(Put, "/")).body, "PUT")
  assert_eq(router.serve(Context::new(Delete, "/")).body, "DELETE")
  assert_eq(router.serve(Context::new(Patch, "/")).body, "PATCH")
  assert_eq(router.serve(Context::new(Head, "/")).body, "HEAD")
  assert_eq(router.serve(Context::new(Options, "/")).body, "OPTIONS")
}

///|
test "httprouter: 404 for unmatched" {
  let router = Router::new()
  router.get("/hi", fn(_ctx) { Response::text("hi") })

  // Partial match should not work
  assert_eq(router.serve(Context::new(Get, "/h")).status, 404)
  assert_eq(router.serve(Context::new(Get, "/hii")).status, 404)
  assert_eq(router.serve(Context::new(Get, "/")).status, 404)
}

///|
test "httprouter: complex nested routes" {
  // Based on various tree tests
  let router = Router::new()
  router.get("/", fn(_ctx) { Response::text("root") })
  router.get("/cmd/:tool/", fn(ctx) {
    Response::text("tool:" + ctx.param("tool").unwrap_or("?"))
  })
  router.get("/cmd/:tool/:sub", fn(ctx) {
    let tool = ctx.param("tool").unwrap_or("?")
    let sub = ctx.param("sub").unwrap_or("?")
    Response::text(tool + "/" + sub)
  })
  router.get("/src/*filepath", fn(ctx) {
    Response::text("src:" + ctx.param("filepath").unwrap_or("?"))
  })
  router.get("/search/", fn(_ctx) { Response::text("search/") })
  router.get("/search/:query", fn(ctx) {
    Response::text("search:" + ctx.param("query").unwrap_or("?"))
  })
  assert_eq(router.serve(Context::new(Get, "/")).body, "root")
  assert_eq(router.serve(Context::new(Get, "/cmd/test/")).body, "tool:test")
  assert_eq(router.serve(Context::new(Get, "/cmd/test/3")).body, "test/3")
  assert_eq(
    router.serve(Context::new(Get, "/src/file.txt")).body,
    "src:file.txt",
  )
  assert_eq(
    router.serve(Context::new(Get, "/src/dir/file.txt")).body,
    "src:dir/file.txt",
  )
  assert_eq(router.serve(Context::new(Get, "/search/")).body, "search/")
  assert_eq(
    router.serve(Context::new(Get, "/search/moonbit")).body,
    "search:moonbit",
  )
}

///|
test "httprouter: params extraction via context" {
  // Based on TestParams
  let router = Router::new()
  router.get("/users/:userId/posts/:postId/comments/:commentId", fn(ctx) {
    let user = ctx.param("userId").unwrap_or("?")
    let post = ctx.param("postId").unwrap_or("?")
    let comment = ctx.param("commentId").unwrap_or("?")
    Response::text(user + "/" + post + "/" + comment)
  })
  assert_eq(
    router.serve(Context::new(Get, "/users/1/posts/2/comments/3")).body,
    "1/2/3",
  )
}

///|
test "httprouter: missing param returns none" {
  let router = Router::new()
  router.get("/user/:name", fn(ctx) {
    let missing = ctx.param("nonexistent")
    match missing {
      Some(_) => Response::text("found")
      None => Response::text("not found")
    }
  })
  assert_eq(router.serve(Context::new(Get, "/user/test")).body, "not found")
}
