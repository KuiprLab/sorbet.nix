<script>
	import { login } from './session.svelte.js';

	let username = $state('');
	let password = $state('');
	let busy = $state(false);
	let err = $state('');

	async function submit(e) {
		e.preventDefault();
		busy = true;
		err = '';
		try {
			await login(username, password);
		} catch (e2) {
			err = e2.message || 'Login failed';
		} finally {
			busy = false;
		}
	}
</script>

<section class="auth-wrap">
	<div class="auth">
		<header class="auth-head">
			<span class="kicker">/// authenticate</span>
			<h1>Harvest</h1>
			<p>Search MusicBrainz · Pull from Soulseek · Hand off to beets.</p>
		</header>
		<form class="card auth-form" onsubmit={submit}>
			<div class="field">
				<label for="u">username</label>
				<input
					id="u"
					class="input"
					autocomplete="username"
					bind:value={username}
					required
				/>
			</div>
			<div class="field">
				<label for="p">password</label>
				<input
					id="p"
					class="input"
					type="password"
					autocomplete="current-password"
					bind:value={password}
					required
				/>
			</div>
			{#if err}
				<p class="auth-err">{err}</p>
			{/if}
			<button class="btn btn-primary" disabled={busy} type="submit">
				{busy ? 'Connecting…' : 'Enter'}
			</button>
		</form>
	</div>
</section>

<style>
	.auth-wrap {
		min-height: 70vh;
		display: grid;
		place-items: center;
	}
	.auth {
		width: min(420px, 100%);
		display: grid;
		gap: 28px;
	}
	.auth-head {
		text-align: center;
		display: grid;
		gap: 8px;
	}
	.kicker {
		font-family: var(--font-mono);
		font-size: 11px;
		letter-spacing: 0.18em;
		text-transform: uppercase;
		color: var(--accent);
	}
	h1 {
		margin: 0;
		font-family: var(--font-display);
		font-size: clamp(40px, 8vw, 64px);
		letter-spacing: -0.03em;
		font-weight: 700;
	}
	p {
		margin: 0;
		color: var(--text-dim);
		font-family: var(--font-mono);
		font-size: 12px;
		letter-spacing: 0.04em;
	}
	.auth-form {
		display: grid;
		gap: 16px;
		box-shadow: var(--shadow-glow);
	}
	.auth-err {
		color: var(--danger);
		font-family: var(--font-mono);
		font-size: 12px;
	}
</style>
