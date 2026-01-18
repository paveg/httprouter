# httprouter

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![MoonBit](https://img.shields.io/badge/MoonBit-v0.1.0-purple.svg)](https://www.moonbitlang.com/)

A high-performance HTTP router for [MoonBit](https://www.moonbitlang.com/), inspired by [julienschmidt/httprouter](https://github.com/julienschmidt/httprouter).

## Prerequisites

This project requires the **MoonBit toolchain**. Install it from the official website:

- 🌙 [MoonBit](https://www.moonbitlang.com/) - A modern programming language optimized for WebAssembly

```bash
# Verify installation
moon version
```

## Installation

```bash
moon add paveg/httprouter
```

## Development

```bash
# Build the project
moon build

# Run tests
moon test

# Format code
moon fmt

# Check for errors without building
moon check
```

## Packages

- `paveg/httprouter/src/lib`: Core router implementation

## Features

- [x] Path parameters (`:id`)
- [x] Wildcard parameters (`*path`)
- [x] Static route priority (static routes match before parameterized routes)
- [x] HTTP method matching (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS)
- [x] Custom 404/405 handlers
- [x] Global middleware support
- [x] Response helpers (text, json, html, redirect)
- [x] Fetch API adapter (Cloudflare Workers, Deno, etc.)
- [ ] Radix tree optimization (planned)

## Usage

### Basic Routing

```moonbit
let router = @lib.Router::new()

router.get("/", fn(_ctx) { @lib.Response::text("Hello, World!") })

router.get("/users/:id", fn(ctx) {
  match ctx.param("id") {
    Some(id) => @lib.Response::json("{\"id\": \"" + id + "\"}")
    None => @lib.Response::not_found()
  }
})

router.post("/users", fn(ctx) {
  @lib.Response::json("{\"created\": true}", status=201)
})
```

### Path Parameters

Use `:name` to capture path segments:

```moonbit
// Matches /users/123, /users/abc, etc.
router.get("/users/:id", fn(ctx) {
  let id = ctx.param("id") // Some("123")
  // ...
})

// Multiple parameters
router.get("/users/:userId/posts/:postId", fn(ctx) {
  let user_id = ctx.param("userId")
  let post_id = ctx.param("postId")
  // ...
})
```

### Wildcard Parameters

Use `*name` to capture the rest of the path (must be at the end):

```moonbit
// Matches /files/a/b/c.txt -> path = "a/b/c.txt"
router.get("/files/*path", fn(ctx) {
  let path = ctx.param("path") // Some("a/b/c.txt")
  // ...
})
```

### Route Priority

Static routes always take precedence over parameterized routes:

```moonbit
router.get("/users/:id", fn(_ctx) { @lib.Response::text("param") })
router.get("/users/me", fn(_ctx) { @lib.Response::text("static") })

// GET /users/me   -> "static"
// GET /users/123  -> "param"
```

### Custom Error Handlers

```moonbit
router.set_not_found(fn(_ctx) {
  @lib.Response::json("{\"error\": \"Not Found\"}", status=404)
})

router.set_method_not_allowed(fn(allowed) {
  let methods = allowed.map(fn(m) { m.to_string() }).join(", ")
  @lib.Response::text("Allowed: " + methods, status=405)
})
```

### Middleware

```moonbit
// Add global middleware
router.add_middleware(fn(ctx) {
  // Return Some(ctx) to continue, None to short-circuit
  if ctx.header("Authorization") is Some(_) {
    Some(ctx)
  } else {
    None // Returns 403 Forbidden
  }
})
```

### Declarative Route Definition

```moonbit
let router = @lib.Router::from_routes([
  (@lib.Get, "/", fn(_ctx) { @lib.Response::text("home") }),
  (@lib.Get, "/about", fn(_ctx) { @lib.Response::text("about") }),
  (@lib.Post, "/api/users", fn(_ctx) { @lib.Response::json("{}") }),
])
```

### Fetch API Adapter

For Cloudflare Workers, Deno Deploy, and other Fetch API-compatible platforms:

```moonbit
let router = @lib.Router::new()
router.get("/hello", fn(_ctx) { @lib.Response::text("Hello!") })

// Handle Fetch API request
let request = @lib.FetchRequest::new(
  "GET",
  "https://example.com/hello?name=world",
  headers=[("Accept", "text/plain")],
)
let response = router.fetch(request)
// response.status = 200
// response.body = "Hello!"
```

### Response Helpers

```moonbit
@lib.Response::text("Hello")                    // 200 text/plain
@lib.Response::text("Error", status=500)        // 500 text/plain
@lib.Response::json("{\"ok\":true}")            // 200 application/json
@lib.Response::html("<h1>Hello</h1>")           // 200 text/html
@lib.Response::redirect("/new-location")        // 302 redirect
@lib.Response::redirect("/new", status=301)     // 301 permanent redirect
@lib.Response::not_found()                      // 404
@lib.Response::method_not_allowed([Get, Post])  // 405 with Allow header
```

## API Reference

### Types

| Type | Description |
|------|-------------|
| `Router` | HTTP router with route registration and request handling |
| `Context` | Request context with path, params, headers, body |
| `Response` | HTTP response with status, headers, body |
| `Method` | HTTP method enum (Get, Post, Put, Delete, Patch, Head, Options) |
| `Params` | Collection of path parameters |
| `FetchRequest` | Fetch API compatible request |
| `FetchResponse` | Fetch API compatible response |

### Router Methods

| Method | Description |
|--------|-------------|
| `Router::new()` | Create a new router |
| `Router::from_routes(routes)` | Create router from route array |
| `router.get(path, handler)` | Register GET route |
| `router.post(path, handler)` | Register POST route |
| `router.put(path, handler)` | Register PUT route |
| `router.delete(path, handler)` | Register DELETE route |
| `router.patch(path, handler)` | Register PATCH route |
| `router.head(path, handler)` | Register HEAD route |
| `router.options(path, handler)` | Register OPTIONS route |
| `router.handle(method, path, handler)` | Register route with any method |
| `router.serve(ctx)` | Handle a request and return response |
| `router.fetch(request)` | Handle a FetchRequest and return FetchResponse |
| `router.set_not_found(handler)` | Set custom 404 handler |
| `router.set_method_not_allowed(handler)` | Set custom 405 handler |
| `router.add_middleware(mw)` | Add global middleware |

## License

Apache-2.0
