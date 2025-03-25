/**
 * Bash syntax v 1.0 
 *   
**/
editAreaLoader.load_syntax["bash"] = {
	'DISPLAY_NAME': 'Bash'
	, 'COMMENT_SINGLE': { 1: '#' }
	, 'COMMENT_MULTI': {}
	, 'QUOTEMARKS': { 1: "'", 2: '"' }
	, 'KEYWORD_CASE_SENSITIVE': true
	, 'KEYWORDS': {
		'reserved': [
			'case', 'easc', 'if', 'fi', 'function', 'else', 'elif', 'for', 'while', 'until', 'let',
			'expr', 'echo', 'export', 'true', 'false', 'done', 'declare',
			'-a', '-i', '-l', '-u', '-r', 'exit', 'read', 'printf',
			'return', 'grep', 'ps', 'do', 'kill', 'cat', 'cut', 'tr'
		]
	}
	, 'OPERATORS': [
		'+', '-', '/', '*', '=', '<', '>', '%', '!', '&', ';', '?', '`', ':', ','
	]
	, 'DELIMITERS': [
		'(', ')', '[', ']', '{', '}'
	]
	, 'REGEXPS': {
		'constants': {
			'search': '()([A-Z]\\w*)()'
			, 'class': 'constants'
			, 'modifiers': 'g'
			, 'execute': 'before'
		}
		, 'variables': {
			'search': '()([\$\@\%]+\\w+)()'
			, 'class': 'variables'
			, 'modifiers': 'g'
			, 'execute': 'before'
		}
		, 'numbers': {
			'search': '()(-?[0-9]+)()'
			, 'class': 'numbers'
			, 'modifiers': 'g'
			, 'execute': 'before'
		}
		, 'symbols': {
			'search': '()(:\\w+)()'
			, 'class': 'symbols'
			, 'modifiers': 'g'
			, 'execute': 'before'
		}
	}
	, 'STYLES': {
		'COMMENTS': 'color: #AAAAAA;'
		, 'QUOTESMARKS': 'color: #660066;'
		, 'KEYWORDS': {
			'reserved': 'font-weight: bold; color: #0000FF;'
		}
		, 'OPERATORS': 'color: #993300;'
		, 'DELIMITERS': 'color: #993300;'
		, 'REGEXPS': {
			'variables': 'color: #E0BD54;'
			, 'numbers': 'color: green;'
			, 'constants': 'color: #00AA00;'
			, 'symbols': 'color: #879EFA;'
		}
	}
};
