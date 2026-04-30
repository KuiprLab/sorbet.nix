import { api } from "./api.js";

export const session = $state({
  user: null,
  loading: true,
  error: null,
});

export async function refreshSession() {
  session.loading = true;
  try {
    const me = await api.me();
    session.user = me.username;
    session.error = null;
  } catch (e) {
    session.user = null;
    if (e.status !== 401) session.error = e.message;
  } finally {
    session.loading = false;
  }
}

export async function login(username, password) {
  const r = await api.login(username, password);
  session.user = r.username;
  return r;
}

export async function logout() {
  await api.logout();
  session.user = null;
}
