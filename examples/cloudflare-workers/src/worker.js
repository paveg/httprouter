/**
 * Cloudflare Workers entry point
 *
 * This file imports the MoonBit-compiled JavaScript module
 * and exposes it as a Cloudflare Worker.
 */

// Import the compiled MoonBit module
// Path will be: target/js/release/build/src/src.js after moon build --target js
import * as moonbit from '../target/js/release/build/src/src.js';

export default {
  async fetch(request, env, ctx) {
    try {
      const url = new URL(request.url);
      const method = request.method;
      const body = request.method !== 'GET' && request.method !== 'HEAD'
        ? await request.text()
        : '';

      // Convert headers to JSON for MoonBit
      const headers = [];
      request.headers.forEach((value, key) => {
        headers.push([key, value]);
      });
      const headersJson = JSON.stringify(headers);

      // Call MoonBit handler
      const resultJson = moonbit.handle_request(method, request.url, headersJson, body);
      const result = JSON.parse(resultJson);

      // Parse response body if it's a string
      let responseBody = result.body;
      try {
        // Try to parse as JSON to pretty-print
        const parsed = JSON.parse(result.body);
        responseBody = JSON.stringify(parsed);
      } catch {
        // Keep as-is if not valid JSON
      }

      return new Response(responseBody, {
        status: result.status,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
      });
    } catch (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
      });
    }
  },
};
