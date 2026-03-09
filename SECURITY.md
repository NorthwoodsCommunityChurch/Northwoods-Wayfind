# Security Review - Northwoods Wayfind

**Review Date**: 2026-03-01
**Reviewer**: Ben (automated security review)
**App Type**: Node.js HTTP server (signage display)
**Risk Profile**: Network-facing (HTTP server, API proxy, static file serving)

---

## Summary

Northwoods Wayfind is a Node.js HTTP server that serves a digital signage display and proxies requests to the eSpace API. It has a path traversal vulnerability in static file serving, unrestricted CORS on the API proxy, and an API key that could be exposed. The server is designed to run on a dedicated signage display machine.

| Severity | Count |
|----------|-------|
| Critical | 1 |
| High | 2 |
| Medium | 2 |
| Low | 2 |
| **Total** | **7** |

---

## Findings

### CRITICAL

#### NW-01: Path traversal in static file serving
- **File**: `server.js` lines 61-62
- **Detail**: The static file serving uses `path.join(__dirname, filePath)` where `filePath` comes directly from the URL pathname. A request like `GET /../../etc/passwd` would resolve to a path outside the web root. While `path.join` collapses `../`, the URL pathname is used directly without sanitization, and the result is not validated to stay within `__dirname`.
- **CWE**: CWE-22 (Improper Limitation of a Pathname to a Restricted Directory)
- **Fix**: After constructing the file path, verify it starts with `__dirname` using `path.resolve()` and a prefix check. Or use a static file middleware like `express.static()` which handles this correctly.

---

### HIGH

#### NW-02: API key exposed in URL construction
- **File**: `server.js` lines 9, 18
- **Detail**: The eSpace API key from the environment variable is embedded directly in the API URL. The API proxy endpoint returns raw API responses to any client, effectively exposing the API key's capabilities to anyone who can reach the server. While the key itself is not directly exposed in responses, the server acts as an unauthenticated proxy to the eSpace API.
- **CWE**: CWE-200 (Exposure of Sensitive Information to an Unauthorized Actor)
- **Fix**: Add authentication to the `/api/events` endpoint, or accept that this is an intentional proxy for the signage display. Restrict access by IP or add a simple token.

#### NW-03: Unrestricted CORS on API proxy
- **File**: `server.js` line 48
- **Detail**: The API proxy response includes `Access-Control-Allow-Origin: *`, allowing any webpage on any origin to make requests to the API proxy. Combined with no authentication, any website can fetch event data through this proxy.
- **CWE**: CWE-942 (Overly Permissive Cross-domain Whitelist)
- **Fix**: Remove the CORS header (it's unnecessary if only the local signage display accesses the API) or restrict to the specific origin.

---

### MEDIUM

#### NW-04: No HTTPS support
- **File**: `server.js` lines 33, 83
- **Detail**: The server uses `http.createServer()` with no TLS. All data including API responses flows over plaintext HTTP.
- **CWE**: CWE-319 (Cleartext Transmission of Sensitive Information)
- **Fix**: Add HTTPS support, or document as local-network-only for dedicated signage hardware.

#### NW-05: No security headers
- **File**: `server.js`
- **Detail**: No security headers are set (no CSP, X-Frame-Options, X-Content-Type-Options, etc.). The server returns raw content with only Content-Type headers.
- **CWE**: CWE-693 (Protection Mechanism Failure)
- **Fix**: Add basic security headers to all responses.

---

### LOW

#### NW-06: Error messages in API proxy
- **File**: `server.js` lines 52-56
- **Detail**: API proxy errors are logged to the console with full error details. While the client response is generic (`"Failed to fetch events"`), the server-side logging could expose sensitive request details.
- **Fix**: Ensure logs are not accessible to unauthorized users.

#### NW-07: No rate limiting on API proxy
- **File**: `server.js`
- **Detail**: The `/api/events` endpoint has no rate limiting. An attacker could use the proxy to flood the eSpace API, potentially exhausting rate limits or API quota.
- **Fix**: Add basic rate limiting to the API proxy endpoint.

---

## Architecture Notes

- **Server**: Plain Node.js `http.createServer()` (no Express, no middleware)
- **Static files**: Served from `__dirname` using `fs.readFile()`
- **API proxy**: Proxies to `app.espace.cool` for event data
- **Credentials**: eSpace API key in `.env` file (gitignored)
- **Use case**: Dedicated signage display for building wayfinding
- **Display ID**: Configurable via `ESPACE_DISPLAY_ID` env var
