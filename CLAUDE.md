# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
moon build          # Build the project
moon test           # Run all tests
moon test --update  # Update test snapshots
moon check          # Lint check
moon fmt            # Format code
moon info           # Generate/update .mbti interface files
moon coverage analyze  # Check code coverage
```

After changes: `moon info && moon fmt` to update interfaces and format.

## Architecture

This is an HTTP router library for MoonBit with linear O(n) route matching, prioritized by static routes.

### Core Types (src/lib/)

```
Router
├── routes: Array[Route]          # Routes sorted by priority
├── middleware: Array[Middleware] # Global middleware chain
├── not_found_handler
└── method_not_allowed_handler

Route
├── http_method: Method
├── path: String
├── segments: Array[Segment]      # Parsed for matching
└── handler: (Context) -> Response

Segment = Static(String) | Param(String) | Wildcard(String)

Context                           # Request info
├── http_method, path, query
├── params: Params                # Extracted path params
├── headers, body

Response                          # HTTP response
├── status, headers, body
└── helpers: text(), json(), html(), redirect(), not_found()
```

### Route Matching

1. **Priority**: Static routes → more static segments → registration order
2. **Patterns**: `/users` (static), `/users/:id` (param), `/files/*path` (wildcard)
3. **Lookup**: Returns `Found | MethodNotAllowed | NotFound`

### File Conventions

- `*_test.mbt` - Blackbox tests
- `*_wbtest.mbt` - Whitebox tests
- `deprecated.mbt` - Keep deprecated code here
- Code blocks separated by `///|` (order-irrelevant)

## Testing

Use `assert_eq!`, `assert_true!`, `assert_false!` macros. Prefer `inspect` with snapshots over assertions in loops.

## Roadmap

- マルチバックエンド対応を検討中（Cloudflare Workers / Wasm等）
