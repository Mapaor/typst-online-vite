<script lang="ts">
	import { goto } from '$app/navigation';
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';

	type UILang = 'zh' | 'en';
	const LANG_STORAGE_KEY = 'mdxport_lang';
	const DEFAULT_LANG: UILang = 'en';

	function detectPreferredLang(): UILang {
		try {
			const saved = localStorage.getItem(LANG_STORAGE_KEY);
			if (saved === 'zh' || saved === 'en') return saved;
		} catch {
			// ignore
		}

		const nav = (navigator.language || '').toLowerCase();
		return nav.startsWith('zh') ? 'zh' : 'en';
	}

	onMount(() => {
		if (!browser) return;
		const target = detectPreferredLang();
		void goto(`/${target}/`, { replaceState: true });
	});
</script>

<svelte:head>
	<title>MDXport · Markdown to PDF, Perfect Typesetting</title>
	<meta name="description" content="A delivery engine for AI-generated content. Runs entirely client-side, your data never leaves your browser. Auto-fix formatting issues with one click." />
	
	<!-- Hreflang for SEO -->
	<link rel="canonical" href="/en/" />
	<link rel="alternate" hreflang="zh-Hans" href="/zh/" />
	<link rel="alternate" hreflang="en" href="/en/" />
	<link rel="alternate" hreflang="x-default" href="/en/" />
	
	<!-- Open Graph -->
	<meta property="og:title" content="MDXport · Markdown to PDF, Perfect Typesetting" />
	<meta property="og:description" content="A delivery engine for AI-generated content. Runs entirely client-side, your data never leaves your browser." />
	<meta property="og:type" content="website" />
	<meta property="og:locale" content="en_US" />
	<meta property="og:locale:alternate" content="zh_CN" />
</svelte:head>

<main class="redirect-page">
	<h1>MDXport</h1>
	<p class="loading">Redirecting...</p>
	<div class="fallback">
		<span>Not redirected?</span>
		<a class="btn" href="/en/">English</a>
		<a class="btn" href="/zh/">中文</a>
	</div>
</main>

<style>
	.redirect-page {
		min-height: 100vh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		text-align: center;
		font-family: var(--font-sans);
		padding: 2rem;
	}

	h1 {
		margin: 0;
		font-size: 2rem;
		font-weight: 700;
		letter-spacing: -0.02em;
	}

	.loading {
		margin: 0;
		color: var(--color-gray-500);
		font-size: 0.9rem;
	}

	.fallback {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		margin-top: 1rem;
		flex-wrap: wrap;
		justify-content: center;
	}

	.fallback span {
		color: var(--color-gray-400);
		font-size: 0.875rem;
	}

	.btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		padding: 0.5rem 1rem;
		border-radius: 8px;
		background: var(--color-gray-900);
		color: var(--color-white);
		font-size: 0.875rem;
		font-weight: 500;
		text-decoration: none;
		transition: background 0.15s ease;
	}

	.btn:hover {
		background: var(--color-gray-700);
	}
</style>
