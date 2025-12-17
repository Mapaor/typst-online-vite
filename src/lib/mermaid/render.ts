import mermaid from 'mermaid';

let initialized = false;

const encoder = new TextEncoder();

/**
 * Initialize mermaid if not already
 */
function init() {
	if (initialized) return;
	mermaid.initialize({
		startOnLoad: false,
		theme: 'neutral', // Better for tech docs
		securityLevel: 'loose', // Needed for some charts?
		fontFamily: 'sans-serif',
		htmlLabels: false, // Critical for Typst SVG support
		flowchart: { htmlLabels: false }
	});
	initialized = true;
}

/**
 * Render mermaid code to SVG Uint8Array
 */
export async function renderMermaidToSvg(code: string, id: string): Promise<Uint8Array> {
	init();
	try {
		// mermaid.render returns an object with svg property in v10+
		const { svg } = await mermaid.render(id, code);
		return encoder.encode(svg);
	} catch (error) {
		console.error('Mermaid render error:', error);
		// Return error SVG/placeholder
		return encoder.encode(
			`<svg width="200" height="50" xmlns="http://www.w3.org/2000/svg"><text x="10" y="30" fill="red">Mermaid Error</text></svg>`
		);
	}
}
