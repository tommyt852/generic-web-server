/**
 * Localhost API helper for pages served by web.ps1.
 * Token comes only from <meta name="local-token"> injected by the server.
 * Do not store the token in localStorage or the URL.
 */

function readLocalToken() {
  const el = document.querySelector('meta[name="local-token"]');
  return el && el.content ? el.content : "";
}

async function parseBody(response) {
  const text = await response.text();
  const contentType = response.headers.get("content-type") || "";
  let json = null;
  if (contentType.includes("application/json")) {
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      json = null;
    }
  }
  return { response, text, json, ok: response.ok, status: response.status };
}

/**
 * @param {string} path e.g. "/api/hello"
 * @param {RequestInit} [init]
 */
export async function apiGet(path, init = {}) {
  const headers = new Headers(init.headers || {});
  const token = readLocalToken();
  if (token) headers.set("X-Local-Token", token);
  const response = await fetch(path, {
    ...init,
    method: "GET",
    headers,
    credentials: "same-origin",
  });
  return parseBody(response);
}

/**
 * @param {string} path
 * @param {unknown} [body] object -> JSON, string -> raw
 * @param {RequestInit} [init]
 */
export async function apiPost(path, body, init = {}) {
  const headers = new Headers(init.headers || {});
  const token = readLocalToken();
  if (token) headers.set("X-Local-Token", token);
  let payload = body;
  if (body !== undefined && body !== null && typeof body !== "string") {
    headers.set("Content-Type", "application/json; charset=utf-8");
    payload = JSON.stringify(body);
  }
  const response = await fetch(path, {
    ...init,
    method: "POST",
    headers,
    body: payload,
    credentials: "same-origin",
  });
  return parseBody(response);
}

export function getLocalTokenPresent() {
  return Boolean(readLocalToken());
}
