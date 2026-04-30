<script>
	let { result, onpick } = $props();
</script>

<button class="row" onclick={() => onpick(result)} type="button">
	<div class="cover">
		{#if result.cover_url}
			<img src={result.cover_url} alt="" loading="lazy" />
		{:else}
			<span class="cover-fallback">
				{result.title?.slice(0, 2)?.toUpperCase() ?? '??'}
			</span>
		{/if}
	</div>
	<div class="meta">
		<div class="title">{result.title}</div>
		<div class="sub">
			<span>{result.artist}</span>
			{#if result.first_release_date}
				<span class="dot">•</span>
				<span class="mono">{result.first_release_date.slice(0, 4)}</span>
			{/if}
			{#if result.primary_type}
				<span class="dot">•</span>
				<span class="tag">{result.primary_type}</span>
			{/if}
		</div>
	</div>
	<div class="chev" aria-hidden="true">→</div>
</button>

<style>
	.row {
		display: grid;
		grid-template-columns: 72px 1fr auto;
		gap: 16px;
		align-items: center;
		width: 100%;
		text-align: left;
		background: var(--surface);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		padding: 12px;
		color: var(--text);
		transition: border-color 0.18s, transform 0.18s, background 0.18s;
		cursor: pointer;
	}
	.row:hover {
		border-color: var(--border-strong);
		transform: translateX(2px);
		background: var(--surface-2);
	}
	.cover {
		width: 72px;
		height: 72px;
		border-radius: 10px;
		overflow: hidden;
		background: linear-gradient(135deg, oklch(28% 0.1 320), oklch(20% 0.1 280));
		display: grid;
		place-items: center;
		flex: none;
	}
	.cover img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		display: block;
	}
	.cover-fallback {
		font-family: var(--font-mono);
		font-weight: 700;
		font-size: 18px;
		color: oklch(95% 0.05 320);
		letter-spacing: 0.05em;
	}
	.meta {
		min-width: 0;
	}
	.title {
		font-family: var(--font-display);
		font-size: 18px;
		font-weight: 600;
		letter-spacing: -0.01em;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.sub {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
		align-items: center;
		color: var(--text-dim);
		font-family: var(--font-mono);
		font-size: 12px;
		margin-top: 4px;
	}
	.sub .dot {
		color: var(--text-muted);
	}
	.sub .tag {
		font-size: 10px;
		padding: 2px 8px;
		border: 1px solid var(--border);
		border-radius: 999px;
		text-transform: uppercase;
		letter-spacing: 0.1em;
	}
	.chev {
		color: var(--text-muted);
		font-family: var(--font-mono);
		font-size: 18px;
		padding-right: 6px;
	}
</style>
