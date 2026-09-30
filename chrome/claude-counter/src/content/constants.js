(() => {
	'use strict';

	const CC = (globalThis.ClaudeCounter = globalThis.ClaudeCounter || {});

	CC.DOM = Object.freeze({
		CHAT_MENU_TRIGGER: '[data-testid="chat-menu-trigger"]',
		MODEL_SELECTOR_DROPDOWN: '[data-testid="model-selector-dropdown"]',
		CHAT_PROJECT_WRAPPER: '.chat-project-wrapper',
		BRIDGE_SCRIPT_ID: 'cc-bridge-script'
	});

	CC.CONST = Object.freeze({
		CACHE_WINDOW_MS: 5 * 60 * 1000,
		CONTEXT_LIMIT_TOKENS: 200000 // fallback when the model can't be detected
	});

	// Context-window scale (in tokens) used for the chat-length bar, per model family.
	// This is ONLY the visual scale of the "chat length" bar — it does not change your
	// session/weekly usage limits. Adjust these numbers to match your plan if needed.
	// Keys are matched as lowercase substrings against the model selector text.
	CC.MODEL_CONTEXT_LIMITS = Object.freeze([
		['opus', 1000000],
		['sonnet', 1000000],
		['haiku', 200000]
	]);

	// Read the currently selected model from the model-selector dropdown and return the
	// matching context-window size. Falls back to CONTEXT_LIMIT_TOKENS when unknown.
	CC.getContextLimitTokens = function getContextLimitTokens() {
		try {
			const el = document.querySelector(CC.DOM.MODEL_SELECTOR_DROPDOWN);
			const name = (el?.textContent || '').toLowerCase();
			if (name) {
				for (const [key, limit] of CC.MODEL_CONTEXT_LIMITS) {
					if (name.includes(key)) return limit;
				}
			}
		} catch {
			// ignore and fall back
		}
		return CC.CONST.CONTEXT_LIMIT_TOKENS;
	};

	CC.COLORS = Object.freeze({
		PROGRESS_FILL_DARK: '#2c84db',
		PROGRESS_FILL_LIGHT: '#5aa6ff',
		PROGRESS_OUTLINE_DARK: '#787877',
		PROGRESS_OUTLINE_LIGHT: '#bfbfbf',
		PROGRESS_MARKER_DARK: '#ffffff',
		PROGRESS_MARKER_LIGHT: '#111111',
		RED_WARNING: '#ce2029',
		BOLD_LIGHT: '#141413',
		BOLD_DARK: '#faf9f5'
	});
})();
