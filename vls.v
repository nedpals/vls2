module main

import os
import lsp
import strings
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

struct Vls {
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
	show_message(.log, 'Goodbye!')
	exit(int(vls.status != .shutdown))
}

fn (mut vls Vls) initialize(id int, raw string) {
	// init := json2.raw_decode(raw) or {
	// 	emit_parse_error()
	// 	return
	// }
	// TODO: focus on capabilities for now
	mut server_capabilities := lsp.ServerCapabilities{
		text_document_sync: 1
		// hover_provider: true
		workspace_symbol_provider: true
		document_symbol_provider: true
	}

	server_capabilities.completion_provider.resolve_provider = false
	// TODO:
	// server_capabilities.signature_help_provider.trigger_characters = ['(', '{']
	// server_capabilities.signature_help_provider.trigger_characters = [',']

	respond(json.encode(JrpcResponse<lsp.InitializeResult>{
		id: id,
		result: lsp.InitializeResult{
			capabilities: server_capabilities
		}
	}))
}

fn (mut vls Vls) execute(payload string) {
	request := json.decode(jsonrpc.Request, payload) or {
		emit_parse_error()
		exit(1)
	}
	if vls.log_requests {
		log_contents := os.read_file(log_file) or { '' }
		os.write_file(log_file, log_contents + payload + '\n')
	}
	if request.method != 'exit' && vls.status == .shutdown {
		emit_error(jsonrpc.invalid_request)
		return
	}
	match request.method {
		'initialize' { vls.initialize(request.id, request.params) }
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
		'textDocument/completion' { vls.completion(request.id, request.params) }
		'textDocument/hover' { vls.hover(request.id, request.params) }
		// 'textDocument/signatureHelp' { vls.signature_help(request.id, request.params) }
		else {
			if vls.status != .initialized {
				emit_error(jsonrpc.server_not_initialized)
			}
			return
		}
	}
}

fn (mut vls Vls) start_loop() {
	for {
		first_line := get_raw_input()
		if first_line.len < 1 || !first_line.starts_with(content_length) {
			continue
		}
		mut buf := strings.new_builder(1)
		mut conlen := first_line[content_length.len..].int()
		$if !windows { conlen++ }
		for conlen > 0 {
			c := C.fgetc(C.stdin)
			$if !windows {
				if c == 10 { continue }
			}
			buf.write_b(byte(c))
			conlen--
		}
		payload := buf.str()
		vls.execute(payload[1..])
		unsafe { buf.free() }
	}
}

fn main() {
	mut vls := Vls{}
	vls.log_requests = os.getenv('VLS_LOG') == '1' || '-log' in os.args
	vls.start_loop()
}
