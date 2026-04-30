<script>
	import { onDestroy, onMount } from 'svelte';
	import { api } from '$lib/api.js';
	import { session } from '$lib/session.svelte.js';
	import Login from '$lib/Login.svelte';

	let jobs = $state([]);
	let err = $state('');
	let timer;

	async function refresh() {
		try {
			const r = await api.listJobs();
			jobs = r.jobs;
			err = '';
		} catch (e) {
			err = e.message;
		}
	}

	onMount(() => {
		refresh();
		timer = setInterval(refresh, 3000);
	});

	onDestroy(() => {
		if (timer) clearInterval(timer);
	});

	function fmtTime(ts) {
		if (!ts) return '—';
		return new Date(ts * 1000).toLocaleTimeString();
	}

	function stateColor(s) {
		switch (s) {
			case 'done':
				return 'ok';
			case 'error':
				return 'bad';
			case 'queued':
				return 'idle';
			default:
				return 'busy';
		}
	}
</script>

{#if !session.user && !session.loading}
	<Login />
{:else}
	<header class="head">
		<span class="kicker">/// downloads</span>
		<h1>Queue</h1>
		<p>Live status of your slskd transfers and post-move handoff.</p>
	</header>

	{#if err}
		<p class="err">{err}</p>
	{/if}

	{#if jobs.length === 0}
		<div class="empty">
			<p>No jobs yet.</p>
			<a href="/" class="btn">Search music</a>
		</div>
	{:else}
		<ul class="jobs">
			{#each jobs as j (j.id)}
				<li class="job">
					<div class="row">
						<div class="title">
							<span class="state state-{stateColor(j.state)}">
								{j.state}
							</span>
							<span class="t">{j.title}</span>
							<span class="a">— {j.artist}</span>
						</div>
						<span class="when">{fmtTime(j.started_at)}</span>
					</div>
					<div class="meta">
						<span>peer: <strong>{j.peer}</strong></span>
						<span class="dot">·</span>
						<span>{j.files.length} file(s)</span>
						<span class="dot">·</span>
						<span>→ {j.target_folder}</span>
					</div>
					{#if j.message}
						<div class="msg">{j.message}</div>
					{/if}
				</li>
			{/each}
		</ul>
	{/if}
{/if}

<style>
	.head {
		text-align: center;
		display: grid;
		gap: 6px;
		padding: clamp(20px, 4vw, 48px) 0 clamp(16px, 3vw, 28px);
	}
	.kicker {
		font-family: var(--font-mono);
		font-size: 11px;
		letter-spacing: 0.22em;
		text-transform: uppercase;
		color: var(--accent);
	}
	h1 {
		margin: 0;
		font-family: var(--font-display);
		font-size: clamp(40px, 8vw, 80px);
		letter-spacing: -0.03em;
	}
	p {
		margin: 0;
		color: var(--text-dim);
		font-family: var(--font-mono);
		font-size: 12px;
	}
	.err {
		text-align: center;
		color: var(--danger);
		font-family: var(--font-mono);
	}
	.empty {
		text-align: center;
		display: grid;
		gap: 16px;
		padding: 60px 12px;
		color: var(--text-muted);
		font-family: var(--font-mono);
	}
	.empty .btn {
		justify-self: center;
	}
	.jobs {
		list-style: none;
		padding: 0;
		margin: 0;
		display: grid;
		gap: 10px;
	}
	.job {
		background: var(--surface);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		padding: 14px 18px;
		display: grid;
		gap: 6px;
	}
	.row {
		display: flex;
		justify-content: space-between;
		gap: 12px;
		align-items: baseline;
		flex-wrap: wrap;
	}
	.title {
		display: flex;
		gap: 10px;
		align-items: center;
		flex-wrap: wrap;
	}
	.state {
		font-family: var(--font-mono);
		font-size: 10.5px;
		letter-spacing: 0.16em;
		text-transform: uppercase;
		padding: 3px 9px;
		border-radius: 999px;
	}
	.state-ok {
		background: oklch(82% 0.18 145);
		color: oklch(15% 0.06 145);
	}
	.state-bad {
		background: var(--danger);
		color: oklch(15% 0.04 25);
	}
	.state-busy {
		background: oklch(72% 0.24 320 / 0.2);
		color: var(--accent);
		border: 1px solid var(--accent);
	}
	.state-idle {
		background: oklch(40% 0.06 295 / 0.4);
		color: var(--text-dim);
	}
	.t {
		font-family: var(--font-display);
		font-size: 18px;
		font-weight: 600;
	}
	.a {
		font-family: var(--font-mono);
		font-size: 13px;
		color: var(--text-dim);
	}
	.when {
		font-family: var(--font-mono);
		color: var(--text-muted);
		font-size: 12px;
	}
	.meta {
		font-family: var(--font-mono);
		font-size: 12px;
		color: var(--text-dim);
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}
	.meta strong {
		color: var(--text);
	}
	.dot {
		color: var(--text-muted);
	}
	.msg {
		font-family: var(--font-mono);
		font-size: 12px;
		color: var(--text-muted);
		padding-top: 4px;
	}
</style>
