<script>
	let {
		query = $bindable(''),
		artist = $bindable(''),
		mode = $bindable('album'),
		busy = false,
		onsearch
	} = $props();

	function submit(e) {
		e.preventDefault();
		if (query.trim().length < 2) return;
		onsearch?.();
	}
</script>

<form class="bar" onsubmit={submit}>
	<div class="bar-inner card">
		<label class="seg seg-q">
			<svg
				viewBox="0 0 24 24"
				width="18"
				height="18"
				fill="none"
				stroke="currentColor"
				stroke-width="2"
				aria-hidden="true"
			>
				<circle cx="11" cy="11" r="7"></circle>
				<path d="m20 20-3.5-3.5"></path>
			</svg>
			<input
				class="bar-input"
				placeholder="Search artist, album or track…"
				bind:value={query}
				autocomplete="off"
				spellcheck="false"
			/>
		</label>

		<div class="seg-divider"></div>

		<label class="seg seg-a">
			<input
				class="bar-input"
				placeholder="Artist (opt)"
				bind:value={artist}
				autocomplete="off"
				spellcheck="false"
			/>
		</label>

		<div class="seg-divider"></div>

		<div class="seg toggle" role="tablist" aria-label="Search type">
			<button
				type="button"
				class="toggle-btn"
				class:active={mode === 'album'}
				onclick={() => (mode = 'album')}
				role="tab"
				aria-selected={mode === 'album'}
			>
				Album
			</button>
			<button
				type="button"
				class="toggle-btn"
				class:active={mode === 'track'}
				onclick={() => (mode = 'track')}
				role="tab"
				aria-selected={mode === 'track'}
			>
				Track
			</button>
		</div>

		<button
			type="submit"
			class="btn btn-primary go"
			disabled={busy || query.trim().length < 2}
		>
			{busy ? 'Searching…' : 'Search'}
		</button>
	</div>
</form>

<style>
	.bar {
		width: min(960px, 100%);
		margin: 0 auto;
	}
	.bar-inner {
		display: grid;
		grid-template-columns: 1.4fr auto 0.9fr auto auto auto;
		align-items: stretch;
		gap: 0;
		padding: 6px;
		border-radius: 999px;
		box-shadow: var(--shadow-glow);
	}
	.seg {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 10px 16px;
		min-width: 0;
		color: var(--text-dim);
	}
	.seg-divider {
		width: 1px;
		background: oklch(45% 0.06 295 / 0.35);
		margin: 10px 0;
	}
	.bar-input {
		background: transparent;
		border: 0;
		outline: 0;
		min-width: 0;
		width: 100%;
		font-family: var(--font-mono);
		font-size: 14px;
		color: var(--text);
	}
	.bar-input::placeholder {
		color: var(--text-muted);
	}
	.toggle {
		gap: 4px;
		padding: 6px;
	}
	.toggle-btn {
		background: transparent;
		border: 0;
		color: var(--text-muted);
		font-family: var(--font-mono);
		font-size: 11px;
		letter-spacing: 0.16em;
		text-transform: uppercase;
		padding: 6px 10px;
		border-radius: 6px;
		transition: background 0.18s, color 0.18s;
	}
	.toggle-btn.active {
		background: oklch(95% 0.05 280);
		color: oklch(15% 0.04 295);
	}
	.toggle-btn:not(.active):hover {
		color: var(--text);
	}
	.go {
		margin: 4px;
		border-radius: 999px;
		padding: 0 22px;
	}

	@media (max-width: 880px) {
		.bar-inner {
			grid-template-columns: 1fr;
			border-radius: var(--radius);
			padding: 12px;
			gap: 10px;
		}
		.seg-divider {
			display: none;
		}
		.seg {
			padding: 12px 14px;
			background: oklch(13% 0.04 295);
			border-radius: var(--radius-sm);
		}
		.toggle {
			justify-content: center;
		}
		.go {
			width: 100%;
			padding: 14px;
			margin: 0;
		}
	}
</style>
