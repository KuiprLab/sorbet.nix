<script>
	import { session } from '$lib/session.svelte.js';
	import Login from '$lib/Login.svelte';
</script>

{#if !session.user && !session.loading}
	<Login />
{:else}
	<header class="head">
		<span class="kicker">/// about</span>
		<h1>How it works</h1>
	</header>

	<section class="grid">
		<article class="step">
			<span class="n">01</span>
			<h2>Search MusicBrainz</h2>
			<p>
				Free-form artist + album/track lookup. Cover art comes from the
				Cover Art Archive. No tracking, no algorithmic mush — just the
				canonical metadata.
			</p>
		</article>

		<article class="step">
			<span class="n">02</span>
			<h2>Pick a peer on Soulseek</h2>
			<p>
				Harvest queries slskd over its API and ranks responses by free
				upload slot, speed, and queue length. Pick the peer, pick the
				files.
			</p>
		</article>

		<article class="step">
			<span class="n">03</span>
			<h2>Download, then hand off</h2>
			<p>
				Files land in the slskd downloads volume. Once complete,
				Harvest moves them to your chosen folder — by default, the
				beets watch inbox, which auto-tags and shelves into
				<code>~/music</code>.
			</p>
		</article>
	</section>

	<footer class="meta">
		<a href="https://musicbrainz.org" target="_blank" rel="noreferrer">
			MusicBrainz
		</a>
		<span>·</span>
		<a href="https://github.com/slskd/slskd" target="_blank" rel="noreferrer">
			slskd
		</a>
		<span>·</span>
		<a href="https://beets.io" target="_blank" rel="noreferrer">beets</a>
	</footer>
{/if}

<style>
	.head {
		text-align: center;
		display: grid;
		gap: 6px;
		padding: clamp(20px, 4vw, 48px) 0 clamp(24px, 4vw, 40px);
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
	.grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
		gap: 16px;
	}
	.step {
		background: var(--surface);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		padding: 24px;
		display: grid;
		gap: 10px;
	}
	.n {
		font-family: var(--font-mono);
		font-size: 11px;
		letter-spacing: 0.2em;
		color: var(--accent-2);
	}
	.step h2 {
		margin: 0;
		font-family: var(--font-display);
		font-size: 22px;
		letter-spacing: -0.01em;
	}
	.step p {
		margin: 0;
		font-family: var(--font-sans);
		color: var(--text-dim);
		font-size: 14px;
		line-height: 1.55;
	}
	.step code {
		font-family: var(--font-mono);
		background: oklch(13% 0.04 295);
		padding: 1px 6px;
		border-radius: 4px;
		font-size: 12px;
	}
	.meta {
		text-align: center;
		font-family: var(--font-mono);
		font-size: 12px;
		color: var(--text-muted);
		padding-top: 32px;
	}
	.meta a {
		color: var(--text-dim);
	}
	.meta a:hover {
		color: var(--text);
	}
</style>
