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

This is an HTTP router library for MoonBit with **radix tree O(k)** route matching (k = path depth).

### Core Types (src/lib/)

```
Router
├── tree: RadixTree               # Radix tree for O(k) lookup
├── middleware: Array[Middleware] # Global middleware chain
├── not_found_handler
└── method_not_allowed_handler

RadixTree
└── root: Node                    # Root node of the tree

Node
├── kind: NodeKind                # Static | PrefixParam | Param | Wildcard
├── children: Array[Node]         # Sorted by priority
└── handlers: Array[(Method, Handler)]

NodeKind = Static | PrefixParam | Param | Wildcard  # Priority order

Context                           # Request info
├── http_method, path, query
├── params: Params                # Extracted path params
├── headers, body

Response                          # HTTP response
├── status, headers, body
└── helpers: text(), json(), html(), redirect(), not_found()
```

### Route Matching (Radix Tree)

1. **Complexity**: O(k) where k = path depth (vs O(n) linear scan)
2. **Priority**: Static → PrefixParam → Param → Wildcard (enforced by tree structure)
3. **Patterns**: `/users` (static), `/user_:name` (prefix+param), `/users/:id` (param), `/files/*path` (wildcard)
4. **Lookup**: Returns `Found(handler, params) | MethodNotAllowed(methods) | NotFound`
5. **Backtracking**: On match failure, removes params and tries next priority node

### File Conventions

- `*_test.mbt` - Blackbox tests
- `*_wbtest.mbt` - Whitebox tests
- `deprecated.mbt` - Keep deprecated code here
- Code blocks separated by `///|` (order-irrelevant)

## Testing

Use `assert_eq!`, `assert_true!`, `assert_false!` macros. Prefer `inspect` with snapshots over assertions in loops.

## Roadmap

- [x] Radix tree optimization (O(n) → O(k))
- [x] Cloudflare Workers support (examples/cloudflare-workers)
- [ ] Multi-backend support (Wasm Native, Deno, etc.)
