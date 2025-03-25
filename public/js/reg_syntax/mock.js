/**
 * Bash syntax v 1.0 
 *   
**/
editAreaLoader.load_syntax["mock"] = {
	'DISPLAY_NAME': 'Mock'
	, 'COMMENT_SINGLE': { 1: '#' }
	, 'COMMENT_MULTI': {}
	, 'QUOTEMARKS': { 1: "'" }
	, 'KEYWORD_CASE_SENSITIVE': true
	, 'KEYWORDS': {
		'reserved': [
			'config_opts', 'include', 'skip_if_unavailable', 'enabled', 'gpgcheck', 'gpgkey',
			'metalink', 'baseurl', 'name', 'cost', 'keepcache', 'debuglevel', 'reposdir',
			'logfile', 'retries', 'obsoletes', 'assumeyes', 'syslog_ident', 'syslog_device'
		]
	}
	, 'OPERATORS': [
		'=',
	]
	, 'DELIMITERS': [
	]
	, 'REGEXPS': {
		'constants': {
			'search': '()({%.*%})()'
			, 'class': 'constants'
			, 'modifiers': 'g'
			, 'execute': 'before'
		}
		, 'numbers': {
			'search': '()({.*})()'
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
