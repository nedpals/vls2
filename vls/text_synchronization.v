module vls

import json
import lsp
import v.parser
import v.table
import v.pref
import v.ast
import v.checker

fn (mut ls Vls) did_open(id int, params string) {
	did_open_params := json.decode(lsp.DidOpenTextDocumentParams, params) or { panic(err) }
	source := did_open_params.text_document.text
	ls.show_diagnostics(source, did_open_params.text_document.uri)
}

fn (mut ls Vls) did_change(id int, params string) {
	did_change_params := json.decode(lsp.DidChangeTextDocumentParams, params) or { panic(err) }
	source := did_change_params.content_changes[0].text
	ls.show_diagnostics(source, did_change_params.text_document.uri)
}

fn (ls Vls) show_diagnostics(source string, uri string) {
	scope := ast.Scope{
		parent: 0
	}
	pref := pref.Preferences{
		output_mode: .silent
	}
	table := table.new_table()
	parsed_file := parser.parse_text(source, table, .parse_comments, &pref, &scope)
	mut checker := checker.new_checker(table, &pref)
	//checker.check(parsed_file)
	mut diagnostics := []lsp.Diagnostic{}
	for _, error in parsed_file.errors {
		diagnostics << lsp.Diagnostic{
			range: position_to_range(source, error.pos)
			severity: .error
			message: error.message
		}
	}
	for _, warning in parsed_file.warnings {
		diagnostics << lsp.Diagnostic{
			range: position_to_range(source, warning.pos)
			severity: .warning
			message: warning.message
		}
	}
	ls.publish_diagnostics(uri, diagnostics)
}
