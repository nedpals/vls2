module vls_old

import os
import lsp
import jsonrpc
import json
// import x.json2
import v.pref
import v.doc
import v.ast
import v.token
import v.table
import v.fmt
import v.checker

// TODO: free strings

const (
	log_file = os.resource_abs_path('output.txt')
	vls_prefs = &pref.Preferences{
		output_mode: .silent
		enable_globals: true
	}
	global_scope = &ast.Scope{ parent: 0 }
	scope = &ast.Scope{
		start_pos: 0
		parent: global_scope
	}
)

pub struct Vls {
mut:
	log_requests bool
	table &table.Table = table.new_table()
	status ServerStatus = .initializing
	// imports
	import_graph map[string][]string
	mod_import_paths map[string]string
	mod_docs map[string]doc.Doc
	// directory -> file name
	projects map[string]Project
	docs map[string]doc.Doc
	tokens map[string]map[string][]token.Token
	asts map[string]map[string]ast.File
	current_file string
}

enum ServerStatus {
	initializing
	initialized
	shutdown
}

fn (mut vls Vls) new_project(project_dir string) {
	vls.projects[project_dir] = Project{
		path: project_dir
		active_files: []string{}
		cached_symbols: []lsp.SymbolInformation{}
		cached_completion: []lsp.CompletionItem{}
		nr_errors: 0
	}
	vls.docs[project_dir] = doc.Doc{
		base_path: project_dir
		prefs: vls_prefs
		pub_only: false
		with_head: false
		extract_vars: true
		fmt: fmt.Fmt{
			indent: 0
			is_debug: false
			table: vls.table
		}
		sources: map[string]string{}
		checker: checker.new_checker(vls.table, vls_prefs)
	}
	vls.tokens[project_dir] = map[string][]token.Token{}
	vls.asts[project_dir] = map[string]ast.File{}
}

fn (mut vls Vls) shutdown() {
	vls.status = .shutdown
	unsafe {
		vls.projects.free()
		vls.mod_import_paths.free()
		vls.import_graph.free()
		vls.mod_docs.free()
	}
	// move exit to shutdown for now
	exit(int(vls.status != .shutdown))
}

fn (mut vls Vls) initialize(id int, raw string) string {
	// init := json2.raw_decode(raw) or {
	// 	emit_parse_error()
	// 	return
	// }
	// TODO: focus on capabilities for now
	mut capabilities := lsp.ServerCapabilities{
		text_document_sync: 1
		// hover_provider: true
		workspace_symbol_provider: true
		document_symbol_provider: true
		completion_provider: lsp.CompletionOptions{
			resolve_provider: false
		}
	}

	// TODO:
	// server_capabilities.signature_help_provider.trigger_characters = ['(', '{']
	// server_capabilities.signature_help_provider.trigger_characters = [',']
	result := JrpcResponse<lsp.InitializeResult>{
		id: id,
		result: lsp.InitializeResult{
			capabilities: capabilities
		}
	}
	return result_message(result)
}

pub fn (mut vls Vls) execute(payload string) ?string {
	request := json.decode(jsonrpc.Request, payload) or {
		return parse_error_message()
	}
	if vls.log_requests {
		log_contents := os.read_file(log_file) or { '' }
		os.write_file(log_file, log_contents + payload + '\n')
	}
	if request.method != 'exit' && vls.status == .shutdown {
		return error_message(jsonrpc.invalid_request)
	}
	match request.method {
		'initialize' { return vls.initialize(request.id, request.params) }
		'initialized' { vls.status = .initializing }
		'shutdown' { vls.shutdown() }
		'exit' { /* ignore */ }
		'workspace/didChangeWatchedFiles' { vls.did_change_watched_files(request.params) }
		'workspace/symbol' { vls.workspace_symbol(request.id, request.params) }
		'textDocument/didOpen' { vls.open_file(request.params) }
		'textDocument/didChange' { vls.change_file(request.params) }
		'textDocument/didSave' { vls.save_file(request.params) }
		'textDocument/didClose' { vls.close_file(request.params) }
		'textDocument/documentSymbol' { vls.document_symbol(request.id, request.params) }
		// 'textDocument/completion' { vls.completion(request.id, request.params) }
		'textDocument/hover' { vls.hover(request.id, request.params) }
		// 'textDocument/signatureHelp' { vls.signature_help(request.id, request.params) }
		else {
			if vls.status != .initialized {
				return error_message(jsonrpc.server_not_initialized)
			}
		}
	}
}