<script>
	import { fmtBytes, fmtDuration } from './api.js';

	let { files = [], selected = $bindable(new Set()) } = $props();

	function toggle(name) {
		const next = new Set(selected);
		if (next.has(name)) next.delete(name);
		else next.add(name);
		selected = next;
	}

	function selectAll() {
		selected = new Set(files.map((f) => f.filename));
	}

	function clear() {
		selected = new Set();
	}

	const audioExts = new Set([
		'flac',
		'mp3',
		'ogg',
		'opus',
		'm4a',
		'wav',
		'aac',
		'aiff'
	]);
	const audioFiles = $derived(
		files.filter((f) =>
			audioExts.has((f.extension || f.filename.split('.').pop() || '').toLowerCase())
		)
	);
</script>

<div class="picker-head">
	<div>
		<span class="count">
			{selected.size}<span class="of">/{audioFiles.length}</span>
		</span>
		<span class="lbl">selected</span>
	</div>
	<div class="actions">
		<button
			type="button"
			class="btn btn-ghost"
			onclick={() => (selected = new Set(audioFiles.map((f) => f.filename)))}
		>
			Audio only
		</button>
		<button type="button" class="btn btn-ghost" onclick={selectAll}>
			Select all
		</button>
		<button type="button" class="btn btn-ghost" onclick={clear}>Clear</button>
	</div>
</div>

<ul class="files">
	{#each files as f (f.filename)}
		{@const ext = (f.extension || f.filename.split('.').pop() || '').toLowerCase()}
		{@const name = f.filename.split('/').pop() || f.filename}
		{@const isAudio = audioExts.has(ext)}
		<li class:non-audio={!isAudio}>
			<label>
				<input
					type="checkbox"
					checked={selected.has(f.filename)}
					onchange={() => toggle(f.filename)}
				/>
				<span class="name" title={f.filename}>{name}</span>
				<span class="meta">
					{#if f.length}
						<span>{fmtDuration(f.length * 1000)}</span>
						<span class="dot">·</span>
					{/if}
					<span>{fmtBytes(f.size)}</span>
				</span>
				<span class="ext tag">{ext.toUpperCase()}</span>
			</label>
		</li>
	{/each}
</ul>

<style>
	.picker-head {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 12px;
		padding-bottom: 12px;
		flex-wrap: wrap;
	}
	.count {
		font-family: var(--font-mono);
		font-size: 24px;
		font-weight: 700;
		color: var(--accent-2);
	}
	.of {
		color: var(--text-muted);
		font-weight: 400;
	}
	.lbl {
		font-family: var(--font-mono);
		font-size: 11px;
		text-transform: uppercase;
		letter-spacing: 0.16em;
		color: var(--text-muted);
		margin-left: 8px;
	}
	.actions {
		display: flex;
		gap: 6px;
		flex-wrap: wrap;
	}
	.files {
		list-style: none;
		padding: 0;
		margin: 0;
		display: grid;
		gap: 4px;
		max-height: 60vh;
		overflow: auto;
	}
	.files li {
		border-radius: var(--radius-sm);
	}
	.files label {
		display: grid;
		grid-template-columns: auto 1fr auto auto;
		gap: 12px;
		align-items: center;
		padding: 10px 12px;
		cursor: pointer;
		border-radius: var(--radius-sm);
		transition: background 0.15s;
	}
	.files label:hover {
		background: oklch(20% 0.05 295 / 0.4);
	}
	.files .non-audio label {
		opacity: 0.45;
	}
	input[type='checkbox'] {
		width: 16px;
		height: 16px;
		accent-color: var(--accent-2);
	}
	.name {
		font-family: var(--font-mono);
		font-size: 13px;
		min-width: 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}
	.meta {
		font-family: var(--font-mono);
		font-size: 11px;
		color: var(--text-dim);
		display: flex;
		gap: 6px;
	}
	.dot {
		color: var(--text-muted);
	}
	.ext {
		font-size: 10px;
	}
</style>
