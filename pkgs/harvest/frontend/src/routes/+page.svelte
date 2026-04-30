<script>
	import { onMount } from 'svelte';
	import { api } from '$lib/api.js';
	import { session } from '$lib/session.svelte.js';
	import Login from '$lib/Login.svelte';
	import Hero from '$lib/Hero.svelte';
	import SearchBar from '$lib/SearchBar.svelte';
	import ResultCard from '$lib/ResultCard.svelte';
	import PeerList from '$lib/PeerList.svelte';
	import FilePicker from '$lib/FilePicker.svelte';
	import { goto } from '$app/navigation';

	let query = $state('');
	let artist = $state('');
	let mode = $state('album');

	let stage = $state('idle'); // idle | results | detail | peers | submit
	let busy = $state(false);
	let err = $state('');

	let results = $state([]);
	let detail = $state(null);
	let peers = $state([]);
	let selectedPeer = $state(null);
	let selectedFiles = $state(new Set());

	let folders = $state([]);
	let chosenFolder = $state('');

	onMount(async () => {
		try {
			const r = await api.targetFolders();
			folders = r.folders;
			chosenFolder = folders[0] || '';
		} catch (_) {}
	});

	async function doSearch() {
		busy = true;
		err = '';
		try {
			const r = await api.search(query, { artist, kind: mode });
			results = r.results;
			stage = 'results';
		} catch (e) {
			err = e.message;
		} finally {
			busy = false;
		}
	}

	async function pick(r) {
		busy = true;
		err = '';
		try {
			if (r.type === 'release-group') {
				detail = await api.releaseGroup(r.id);
			} else {
				detail = {
					id: r.id,
					title: r.title,
					artist: r.artist,
					cover_url: r.cover_url,
					tracks: []
				};
			}
			stage = 'detail';
			// Auto-kick a slskd search
			await searchPeers();
		} catch (e) {
			err = e.message;
			stage = 'results';
		} finally {
			busy = false;
		}
	}

	async function searchPeers() {
		busy = true;
		err = '';
		const q = `${detail.artist} ${detail.title}`.trim();
		try {
			const r = await api.slskdSearch(q);
			peers = r.peers;
			selectedPeer = peers[0]?.username || null;
			selectedFiles = new Set();
			stage = 'peers';
		} catch (e) {
			err = e.message;
		} finally {
			busy = false;
		}
	}

	const selectedPeerObj = $derived(
		peers.find((p) => p.username === selectedPeer) || null
	);

	async function submitDownload() {
		if (!selectedPeerObj || selectedFiles.size === 0 || !chosenFolder) return;
		busy = true;
		err = '';
		try {
			const files = selectedPeerObj.files.filter((f) =>
				selectedFiles.has(f.filename)
			);
			await api.createJob({
				title: detail.title,
				artist: detail.artist,
				target_folder: chosenFolder,
				peer: selectedPeerObj.username,
				files
			});
			goto('/jobs');
		} catch (e) {
			err = e.message;
		} finally {
			busy = false;
		}
	}

	function back() {
		err = '';
		if (stage === 'peers') stage = 'results';
		else if (stage === 'results') stage = 'idle';
		else stage = 'idle';
	}
</script>

{#if session.loading}
	<div class="loading-screen">
		<span class="spin"></span>
	</div>
{:else if !session.user}
	<Login />
{:else}
	<Hero {mode} />

	<SearchBar
		bind:query
		bind:artist
		bind:mode
		{busy}
		onsearch={doSearch}
	/>

	{#if err}
		<p class="err">{err}</p>
	{/if}

	{#if stage === 'results' && results.length > 0}
		<section class="panel">
			<div class="panel-head">
				<span class="kicker">/// search results</span>
				<span class="meta-ct">{results.length} matches</span>
			</div>
			<div class="results-grid">
				{#each results as r (r.id)}
					<ResultCard result={r} onpick={pick} />
				{/each}
			</div>
		</section>
	{:else if stage === 'results' && !busy}
		<section class="panel empty">
			<p>No matches. Try refining the artist field.</p>
		</section>
	{/if}

	{#if stage === 'peers' && detail}
		<section class="panel detail">
			<button type="button" class="back" onclick={back}>← back</button>

			<div class="detail-head">
				<div class="detail-cover">
					{#if detail.cover_url}
						<img src={detail.cover_url} alt="" />
					{/if}
				</div>
				<div class="detail-text">
					<span class="kicker">/// download</span>
					<h2>{detail.title}</h2>
					<p>
						{detail.artist}
						{#if detail.first_release_date}
							· {detail.first_release_date.slice(0, 4)}
						{/if}
						{#if detail.tracks?.length}
							· {detail.tracks.length} tracks
						{/if}
					</p>
				</div>
			</div>

			<div class="detail-grid">
				<div class="col">
					<h3>Peers <small>({peers.length})</small></h3>
					{#if peers.length === 0 && !busy}
						<p class="muted">
							No peers responded. Try a track-specific query or wait
							a moment.
						</p>
					{/if}
					<PeerList {peers} bind:selected={selectedPeer} />
				</div>

				<div class="col">
					<h3>Files</h3>
					{#if selectedPeerObj}
						<FilePicker
							files={selectedPeerObj.files}
							bind:selected={selectedFiles}
						/>
					{:else}
						<p class="muted">Pick a peer on the left.</p>
					{/if}

					<div class="divider"></div>

					<div class="field">
						<label for="folder">Target folder</label>
						<select
							id="folder"
							class="select"
							bind:value={chosenFolder}
						>
							{#each folders as f (f)}
								<option value={f}>{f}</option>
							{/each}
						</select>
					</div>

					<button
						class="btn btn-primary submit"
						type="button"
						disabled={busy ||
							selectedFiles.size === 0 ||
							!selectedPeer ||
							!chosenFolder}
						onclick={submitDownload}
					>
						{busy ? 'Submitting…' : `Download ${selectedFiles.size} file(s)`}
					</button>
				</div>
			</div>
		</section>
	{/if}

	{#if busy && stage === 'idle'}
		<div class="loader">searching musicbrainz…</div>
	{/if}
{/if}

<style>
	.loading-screen {
		min-height: 50vh;
		display: grid;
		place-items: center;
	}
	.spin {
		width: 32px;
		height: 32px;
		border-radius: 50%;
		border: 2px solid oklch(40% 0.05 295 / 0.4);
		border-top-color: var(--accent-2);
		animation: spin 0.8s linear infinite;
	}
	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.err {
		text-align: center;
		font-family: var(--font-mono);
		font-size: 13px;
		color: var(--danger);
		padding: 12px;
	}

	.panel {
		margin-top: 56px;
		display: grid;
		gap: 16px;
	}
	.panel-head {
		display: flex;
		justify-content: space-between;
		align-items: baseline;
	}
	.kicker {
		font-family: var(--font-mono);
		font-size: 11px;
		letter-spacing: 0.18em;
		text-transform: uppercase;
		color: var(--accent);
	}
	.meta-ct {
		font-family: var(--font-mono);
		font-size: 12px;
		color: var(--text-muted);
	}
	.results-grid {
		display: grid;
		gap: 10px;
	}
	.empty {
		text-align: center;
		color: var(--text-muted);
		font-family: var(--font-mono);
		padding: 40px 12px;
	}

	.detail {
		background: var(--surface);
		border: 1px solid var(--border);
		border-radius: var(--radius);
		padding: clamp(20px, 3vw, 32px);
		display: grid;
		gap: 24px;
		box-shadow: var(--shadow-glow);
	}

	.back {
		justify-self: start;
		background: transparent;
		border: 0;
		color: var(--text-dim);
		font-family: var(--font-mono);
		font-size: 12px;
		letter-spacing: 0.1em;
		text-transform: uppercase;
		padding: 6px 0;
	}
	.back:hover {
		color: var(--text);
	}

	.detail-head {
		display: grid;
		grid-template-columns: 96px 1fr;
		gap: 20px;
		align-items: center;
	}
	.detail-cover {
		width: 96px;
		height: 96px;
		border-radius: 12px;
		overflow: hidden;
		background: linear-gradient(
			135deg,
			oklch(28% 0.1 320),
			oklch(20% 0.1 280)
		);
	}
	.detail-cover img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
	.detail-text h2 {
		margin: 4px 0 6px;
		font-family: var(--font-display);
		font-size: clamp(24px, 3.5vw, 36px);
		letter-spacing: -0.02em;
		color: var(--accent-2);
	}
	.detail-text p {
		margin: 0;
		font-family: var(--font-mono);
		color: var(--text-dim);
		font-size: 13px;
	}

	.detail-grid {
		display: grid;
		grid-template-columns: minmax(0, 0.9fr) minmax(0, 1.4fr);
		gap: 28px;
	}
	@media (max-width: 880px) {
		.detail-grid {
			grid-template-columns: 1fr;
		}
	}

	.col h3 {
		font-family: var(--font-mono);
		font-size: 12px;
		letter-spacing: 0.16em;
		text-transform: uppercase;
		color: var(--text-muted);
		margin: 0 0 12px;
		font-weight: 500;
	}
	.col h3 small {
		color: var(--text-muted);
		font-weight: 400;
	}
	.muted {
		font-family: var(--font-mono);
		font-size: 13px;
		color: var(--text-muted);
	}

	.submit {
		margin-top: 16px;
		width: 100%;
		padding: 14px;
		font-size: 13px;
	}

	.loader {
		text-align: center;
		font-family: var(--font-mono);
		color: var(--text-muted);
		padding: 32px;
	}
</style>
