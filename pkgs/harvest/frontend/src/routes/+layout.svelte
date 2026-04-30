<script>
	import '../styles.css';
	import { onMount } from 'svelte';
	import { session, refreshSession, logout } from '$lib/session.svelte.js';
	import { api } from '$lib/api.js';

	let { children } = $props();

	let health = $state(null);

	onMount(async () => {
		await refreshSession();
		try {
			health = await api.health();
		} catch (_) {}
	});

	async function handleLogout() {
		await logout();
		location.reload();
	}
</script>

<div class="page">
	<header class="topbar">
		<a class="brand" href="/">
			<span class="brand-mark" aria-hidden="true">
				<svg viewBox="0 0 24 24" width="22" height="22">
					<path
						d="M9 7v8.5a2.5 2.5 0 1 1-1.6-2.33V8.6l7-1.6v6.4a2.5 2.5 0 1 1-1.6-2.33V5.8z"
						fill="currentColor"
					/>
				</svg>
			</span>
			<span class="brand-name">HARVEST</span>
		</a>

		<nav class="nav" aria-label="Primary">
			<a href="/" class="nav-link">Search</a>
			<a href="/jobs" class="nav-link">Downloads</a>
			<a href="/about" class="nav-link">About</a>
		</nav>

		<div class="userbar">
			{#if session.user}
				<span class="user-handle">{session.user}</span>
				<button class="btn btn-ghost" onclick={handleLogout}>Logout</button>
			{/if}
		</div>
	</header>

	<main class="main">
		{@render children()}
	</main>

	<footer class="footer">
		{#if health}
			<span class="status status-{health.slskd ? 'ok' : 'bad'}">
				<span class="dot"></span> slskd
			</span>
			<span class="status status-{health.beets_inbox_writable ? 'ok' : 'bad'}">
				<span class="dot"></span> beets inbox
			</span>
			<span class="status status-meta">v{health.version}</span>
		{/if}
	</footer>
</div>
