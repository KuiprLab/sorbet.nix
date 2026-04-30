<script>
	import { fmtBytes, fmtSpeed } from './api.js';

	let { peers = [], selected = $bindable(null) } = $props();
</script>

<div class="list">
	{#each peers as peer, i (peer.username)}
		{@const total = peer.files.reduce((s, f) => s + (f.size || 0), 0)}
		<button
			type="button"
			class="peer"
			class:active={selected === peer.username}
			onclick={() => (selected = peer.username)}
		>
			<div class="head">
				<span class="num">#{String(i + 1).padStart(2, '0')}</span>
				<span class="user">{peer.username}</span>
				{#if peer.has_free_upload_slot}
					<span class="tag tag-accent">FREE SLOT</span>
				{:else}
					<span class="tag">queued · {peer.queue_length}</span>
				{/if}
			</div>
			<div class="stats">
				<span><strong>{peer.file_count}</strong> files</span>
				<span class="dot">·</span>
				<span>{fmtBytes(total)}</span>
				<span class="dot">·</span>
				<span>{fmtSpeed(peer.upload_speed)}</span>
			</div>
		</button>
	{/each}
</div>

<style>
	.list {
		display: grid;
		gap: 10px;
	}
	.peer {
		all: unset;
		cursor: pointer;
		display: grid;
		gap: 6px;
		padding: 14px 16px;
		background: var(--surface);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		transition: border-color 0.18s, background 0.18s;
	}
	.peer:hover {
		border-color: var(--border-strong);
	}
	.peer.active {
		border-color: var(--accent-2);
		background: oklch(82% 0.18 145 / 0.07);
		box-shadow: 0 0 0 1px var(--accent-2);
	}
	.head {
		display: flex;
		gap: 10px;
		align-items: center;
		font-family: var(--font-mono);
		font-size: 13px;
	}
	.num {
		color: var(--text-muted);
	}
	.user {
		flex: 1;
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		color: var(--text);
	}
	.stats {
		font-family: var(--font-mono);
		font-size: 11px;
		color: var(--text-dim);
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}
	.stats strong {
		color: var(--text);
		font-weight: 600;
	}
	.dot {
		color: var(--text-muted);
	}
</style>
