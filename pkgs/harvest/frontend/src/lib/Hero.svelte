<script>
	let { mode = 'album' } = $props();
</script>

<header class="hero">
	<span class="kicker">// {mode === 'album' ? 'release search' : 'track search'}</span>
	<h1>
		Harvest <em>Music.</em>
	</h1>
	<p>Search MusicBrainz · pull via Soulseek · hand off to beets.</p>
</header>

<style>
	.hero {
		display: grid;
		gap: 14px;
		justify-items: center;
		text-align: center;
		padding: clamp(24px, 6vw, 64px) 0 clamp(16px, 3vw, 32px);
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
		font-weight: 700;
		font-size: clamp(48px, 10vw, 112px);
		line-height: 0.95;
		letter-spacing: -0.04em;
	}
	h1 em {
		font-style: italic;
		color: var(--accent-2);
		font-weight: 400;
	}

	p {
		margin: 0;
		color: var(--text-dim);
		font-family: var(--font-mono);
		font-size: clamp(12px, 1.5vw, 14px);
		letter-spacing: 0.04em;
	}
</style>
