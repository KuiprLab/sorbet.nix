// Tiny fetch wrapper. All endpoints are same-origin via Caddy.

async function call(path, opts = {}) {
  const res = await fetch(path, {
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...(opts.headers || {}),
    },
    ...opts,
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  if (res.status === 401) {
    const err = new Error("Unauthorized");
    err.status = 401;
    throw err;
  }
  if (!res.ok) {
    let detail = `HTTP ${res.status}`;
    try {
      const j = await res.json();
      detail = j.detail || detail;
    } catch (_) {}
    throw new Error(detail);
  }
  if (res.status === 204) return null;
  return res.json();
}

export const api = {
  health: () => call("/api/health"),
  me: () => call("/api/me"),
  login: (username, password) =>
    call("/api/login", { method: "POST", body: { username, password } }),
  logout: () => call("/api/logout", { method: "POST" }),
  search: (q, { artist, kind } = {}) => {
    const p = new URLSearchParams({ q, kind: kind || "album" });
    if (artist) p.set("artist", artist);
    return call("/api/search?" + p.toString());
  },
  releaseGroup: (id) => call("/api/release-group/" + encodeURIComponent(id)),
  slskdSearch: (query) =>
    call("/api/slskd/search", { method: "POST", body: { query } }),
  targetFolders: () => call("/api/target-folders"),
  createJob: (payload) => call("/api/jobs", { method: "POST", body: payload }),
  listJobs: () => call("/api/jobs"),
  job: (id) => call("/api/jobs/" + encodeURIComponent(id)),
};

export function fmtBytes(n) {
  if (!n) return "—";
  const u = ["B", "KB", "MB", "GB", "TB"];
  let i = 0;
  while (n >= 1024 && i < u.length - 1) {
    n /= 1024;
    i++;
  }
  return `${n.toFixed(n < 10 && i > 0 ? 1 : 0)} ${u[i]}`;
}

export function fmtDuration(ms) {
  if (!ms) return "—";
  const s = Math.round(ms / 1000);
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m}:${String(r).padStart(2, "0")}`;
}

export function fmtSpeed(bps) {
  if (!bps) return "—";
  return fmtBytes(bps) + "/s";
}
