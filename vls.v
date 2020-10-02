module main

import os
import lsp
import strings
import jsonrpc
import json
// import x.json2
import v.ast
import v.checker
import v.table
import v.pref

const (
	log_file = os.resource_abs_path('output.txt')
)

// TODO: ignore version in files for now.
struct Vls {
mut:
	status ServerStatus = .initializing
	file_contents map[string]string
	files map[string]ast.File
	prefs  &pref.Preferences = &pref.Preferences{ output_mode: .silent }
	table &table.Table = table.new_table()
	checker checker.Checker
}

enum ServerStatus {
	initializing
	initialized
	shutdown
}

// workspace/symbol
fn (mut vls Vls) workspace_symbol(id int, raw string) {
	// _ := json.decode(lsp.WorkspaceSymbolParams, raw) or {
	// 	emit_parse_error()
	// 	return
	// }
	mut symbols := []lsp.SymbolInformation{}
	for filename, file_ast in vls.files {
		stmts := file_ast.stmts

		for stmt in stmts {
			if stmt is ast.ConstDecl {
				for field in stmt.fields {
					symbols << lsp.SymbolInformation{
						name: field.name
						kind: .constant
						location: vls.to_loc(filename, field.pos)
						container_name: field.name 
					}
				}
			} else {
				sym := vls.generate_symbol(filename, stmt) or { continue }
				symbols << sym
			}
		}
	}
	respond(json.encode(JrpcResponse<[]lsp.SymbolInformation>{
		id: id
		result: symbols
	}))
}

// textDocument/documentSymbol
fn (mut vls Vls) document_symbol(id int, raw string) {
	params := json.decode(lsp.DocumentSymbolParams, raw) or {
		emit_parse_error()
		return
	}
	fs_path := get_fspath_from_uri(params.text_document.uri)
	if fs_path.len == 0 {
		return
	}
	file_ast := vls.files[fs_path]
	symbols := vls.provide_symbols(fs_path, file_ast.stmts)
	respond(json.encode(JrpcResponse<[]lsp.DocumentSymbol>{
		id: id
		result: symbols
	}))
}

fn (vls Vls) generate_symbol(file string, stmt ast.Stmt) ?lsp.SymbolInformation {
	match stmt {
		ast.FnDecl {
			return lsp.SymbolInformation{
				name: stmt.name
				kind: .function
				deprecated: stmt.is_deprecated
				location: vls.to_loc(file, stmt.pos)
				container_name: stmt.name 
			}
		}
		ast.StructDecl {
			return lsp.SymbolInformation{
				name: stmt.name
				kind: .@struct
				deprecated: false
				location: vls.to_loc(file, stmt.pos)
				container_name: stmt.name 
			}
		}
		ast.EnumDecl {
			return lsp.SymbolInformation{
				name: stmt.name
				kind: .@enum
				deprecated: false
				location: vls.to_loc(file, stmt.pos)
				container_name: stmt.name 
			}
		}
		else {
			return none
		}
	}
}

fn (mut vls Vls) initialize(id int, raw string) {
	// init := json2.raw_decode(raw) or {
	// 	emit_parse_error()
	// 	return
	// }

	// init_map_capa := init.as_map()['capabilities'].as_map()
	// workspace_capa := init_map_capa['workspace'].as_map()
	// doc_capa := init_map_capa['text_document'].as_map() 

	// TODO: focus on capabilities for now
	mut server_capabilities := lsp.ServerCapabilities{
		text_document_sync: 1 // send full content on each revision for now.
	}

	// if workspace_capa['symbol'].as_map()['dynamic_registration'].bool() {
		server_capabilities.code_lens_provider.resolve_provider = false
		server_capabilities.workspace_symbol_provider = true
		server_capabilities.document_symbol_provider = true
	// }

	// if doc_capa['publish_diagnostics'].as_map()['related_information'].bool() {
		// TODO: options for diagnostics
	// }

	// if doc_capa.completion.dynamic_registration {
	// 	server_capabilities.completion_provider = lsp.CompletionOptions{

	// 	}
	// }
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
		return
	}

	if request.method != 'exit' && vls.status == .shutdown {
		emit_error(jsonrpc.invalid_request)
		return
	}

	match request.method {
		'initialize' { vls.initialize(request.id, request.params) }
		'initialized' { vls.status = .initializing }
		'shutdown' { vls.status = .shutdown }
		'exit' {
			show_message(.log, 'Goodbye!')
			exit(int(vls.status != .shutdown))
		}
		'textDocument/didOpen' { vls.open_file(request.id, request.params) }
		'textDocument/didSave' { vls.save_file(request.id, request.params) }
		'textDocument/didClose' { vls.close_file(request.id, request.params) }
		'workspace/symbol' { vls.workspace_symbol(request.id, request.params) }
		'textDocument/documentSymbol' { vls.document_symbol(request.id, request.params) }
		else {
			if vls.status != .initialized {
				emit_error(jsonrpc.server_not_initialized)
				return
			}
		}
	}
}

fn (mut vls Vls) start_loop() {
	log_requests := os.getenv('VLS_LOG') == '1' || '-log' in os.args

	for {
		first_line := get_raw_input()
		if first_line.len < 1 || !first_line.starts_with(content_length) {
			continue
		}

		mut conlen := first_line[content_length.len..].int()
		$if !windows {
			conlen = conlen + 1
		}
		mut buf := strings.new_builder(200)

		for conlen > 0 {
			mut c := C.fgetc(C.stdin)
			$if !windows {
				if c == 10 { continue }
			}
			buf.write_b(byte(c))
			conlen--
		}

		payload := buf.str()
		if log_requests {
			log_contents := os.read_file(log_file) or { '' }
			os.write_file(log_file, log_contents + payload[1..] + '\n')
		}
		vls.execute(payload[1..])
	}
}

fn main() {
	mut vls := Vls{}
	vls.checker = checker.new_checker(vls.table, vls.prefs)
	vls.start_loop()
}
