// =====================================================================
// CircleGuard k6 - shared auth helper
// =====================================================================
// Logs in against /auth/login once per VU and caches the JWT in a
// module-level variable so subsequent iterations don't hammer the auth
// service (which would skew the gateway/promotion metrics).
// =====================================================================
import http from 'k6/http';
import { check, fail } from 'k6';

const AUTH_URL = __ENV.CG_AUTH_URL || 'http://localhost:8180';
const USERNAME = __ENV.CG_USERNAME || 'perf-test@circleguard.edu';
const PASSWORD = __ENV.CG_PASSWORD || 'perf-test-pass';

// k6 does NOT share state between VUs (each VU has its own JS realm),
// so this cache is per-VU — exactly what we want.
let cachedToken = null;
let cachedAt = 0;
const TTL_MS = 50 * 60 * 1000;   // re-login every 50 min (JWT lives 60)

/**
 * Returns a bearer token for the configured test user. Re-authenticates
 * automatically when the cached token is about to expire. Calls fail()
 * if the auth service is unreachable so the whole VU iteration aborts
 * (rather than getting an avalanche of 401s on downstream calls).
 */
export function getJwt() {
    const now = Date.now();
    if (cachedToken && (now - cachedAt) < TTL_MS) {
        return cachedToken;
    }

    const res = http.post(
        `${AUTH_URL}/api/v1/auth/login`,
        JSON.stringify({ username: USERNAME, password: PASSWORD }),
        {
            headers: { 'Content-Type': 'application/json' },
            tags: { name: 'auth_login' },     // separate metric bucket
        }
    );

    const ok = check(res, {
        'auth login 2xx': (r) => r.status >= 200 && r.status < 300,
        'auth login returns token': (r) => {
            try { return !!(r.json() && r.json().token); }
            catch (_e) { return false; }
        },
    });

    if (!ok) {
        fail(`auth login failed: status=${res.status} body=${res.body}`);
    }

    cachedToken = res.json().token;
    cachedAt = now;
    return cachedToken;
}

/**
 * Convenience: returns a headers object ready to splat into http.* params.
 *
 *   const headers = authHeaders({ 'X-Foo': 'bar' });
 *   http.post(url, body, { headers });
 */
export function authHeaders(extra = {}) {
    return Object.assign(
        {
            'Authorization': `Bearer ${getJwt()}`,
            'Content-Type': 'application/json',
        },
        extra
    );
}
