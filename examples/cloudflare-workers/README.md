# Cloudflare Workers Example

This example demonstrates how to use `httprouter` with Cloudflare Workers.

## Prerequisites

- [MoonBit toolchain](https://www.moonbitlang.com/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/install-and-update/)
- Node.js 18+

## Setup

```bash
# Install dependencies
moon update

# Build MoonBit to JavaScript
moon build --target js
```

## Development

```bash
# Run local development server
wrangler dev
```

## Deploy

```bash
wrangler deploy
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Returns hello message |
| GET | `/users/:id` | Returns user ID from path parameter |
| POST | `/echo` | Echoes request body |

## Example Requests

```bash
# Hello
curl http://localhost:8787/

# Get user
curl http://localhost:8787/users/42

# Echo
curl -X POST http://localhost:8787/echo -d "Hello, World!"
```

## Notes

- This example uses MoonBit's JavaScript target for maximum compatibility
- The Wasm-GC target may work but requires runtime support verification
