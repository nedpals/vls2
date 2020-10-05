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
import v.doc
import v.fmt
import v.scanner

const (
	log_file = os.resource_abs_path('output.txt')
)

// TODO: ignore version in files for now.
struct Vls {
mut:
	status ServerStatus = .initializing
	file_contents map[string]string
	doc_nodes map[string][]doc.DocNode
	scanned map[string][]&scanner.Scanner
	files map[string]ast.File
	prefs  &pref.Preferences = &pref.Preferences{ output_mode: .silent }
	table &table.Table = table.new_table()
	doc doc.Doc
	checker checker.Checker
	// for completion
	saved_completion lsp.CompletionList
	saved_offset int = -1
	saved_filename string
}

enum ServerStatus {
	initializing
	initialized
	shutdown
}

fn (vls Vls) compute_offset(file_path string, line int, col int) int {
	text := vls.file_contents[file_path]
	lines := text.split_into_lines()
	mut offset := 0

	for i, ln in lines {
		if i == line {
			if col > ln.len-1 {
				return -1	
			}
			if ln.len == 0 {
				offset++
				break
			}
			offset += col
			break
		} else {
			offset += ln.len+1
		}
	}

	return offset
}

fn (mut vls Vls) completion(id int, raw string) {
	// use position for now
	params := json.decode(lsp.CompletionParams, raw) or {
		emit_parse_error()
		return
	}
	ctx := params.context
	pos := params.position
	fs_path := get_fspath_from_uri(params.text_document.uri)
	if fs_path.len == 0 {
		return
	}
	file_ast := vls.files[fs_path]
	offset := vls.compute_offset(fs_path, pos.line, pos.character)

	// TODO: will be removed once there is support for on-demand computation
	if ctx.trigger_kind == .invoked && offset != -1 {
		mut items := []lsp.CompletionItem{}
		doc_nodes := vls.doc.generate_from_ast_with_pos(file_ast, offset)
		for node in doc_nodes {
			kind := match node.attrs['category'] {
				'Constants' {
					lsp.CompletionItemKind.constant
				}
				'Enums' {
					lsp.CompletionItemKind.@enum
				}
				'Interfaces' {
					lsp.CompletionItemKind.@interface
				}
				'Structs' {
					lsp.CompletionItemKind.@struct
				}
				'Typedefs' {
					lsp.CompletionItemKind.type_parameter
				}
				'Functions',
				'Methods' {
					lsp.CompletionItemKind.function
				}
				'Variables' {
					lsp.CompletionItemKind.variable
				}
				else {
					lsp.CompletionItemKind.field
				}
			}
			items << lsp.CompletionItem{
				label: node.name
				kind: kind
				detail: node.attrs['return_type']
				documentation: lsp.MarkupContent{
					kind: 'markdown'
					value: node.comment
				}
				deprecated: false
			}
		}

		vls.saved_offset = offset
		vls.saved_filename = fs_path
		vls.saved_completion = lsp.CompletionList{
			is_incomplete: false
			items: items
		}
	}
	respond(json.encode(JrpcResponse<lsp.CompletionList>{
		id: id
		result: vls.saved_completion
	}))
}

// TODO: use scanner for it
fn (vls Vls) offset_to_doc_pos(file_path string, start_pos, end_pos int) doc.DocPos {
	text := vls.file_contents[file_path]
	if start_pos > text.len || end_pos > text.len {
		return doc.DocPos{-1, -1, 0}
	}

	lines := text.split_into_lines()
	len := end_pos - start_pos
	mut line := -1
	mut col := -1
	mut total := start_pos
	mut has_pos := false

	for i, ln in lines {
		for j in 0..ln.len {
			total--
			if total == 0 {
				line = i
				col = j
				has_pos = true
				break
			}
		}
		if has_pos {
			break
		}
	}

	// line - col - len
	return doc.DocPos{line, col, len}
}

fn (mut vls Vls) hover(id int, raw string) {
	params := json.decode(lsp.HoverParams, raw) or {
		emit_parse_error()
		return
	}

	fs_path := get_fspath_from_uri(params.text_document.uri)
	if fs_path.len == 0 {
		return
	}

	pos := params.position
	offset := vls.compute_offset(fs_path, pos.line, pos.character)
	show_message(.info, offset.str())
	if offset == -1 {
		return
	}

	text := vls.file_contents[fs_path]
	mut start_pos := offset
	mut end_pos := offset

	for {
		c := text[end_pos]
		if (c.is_letter() || c.is_digit() || c == `_`) && end_pos < text.len {
			end_pos++
			continue
		}
		break
	}

	for {
		c := text[start_pos]
		if (c.is_letter() || c.is_digit() || c == `_`) && start_pos > 0 {
			start_pos--
			continue
		}
		break
	}

	doc_pos := vls.offset_to_doc_pos(fs_path, start_pos, end_pos)
	if doc_pos.line == -1 && doc_pos.col == -1 {
		return
	}

	line := text.split_into_lines()[doc_pos.line].trim_space()
	if line.starts_with('//') || line.starts_with('/*') {
		return
	}

	range := doc_pos_to_lsp_range({ doc_pos | line: doc_pos.line+1 })
	log_message(.info, range.str())
	respond(json.encode(JrpcResponse<lsp.Hover>{
		id: id
		result: lsp.Hover{
			contents: lsp.MarkedString{
				language: 'v'
				value: text[start_pos..end_pos]
			}
			range: range
		}
	}))
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
		// hover_provider: true
		workspace_symbol_provider: true
		document_symbol_provider: true
	}

	// if workspace_capa['symbol'].as_map()['dynamic_registration'].bool() {
		server_capabilities.code_lens_provider.resolve_provider = false
	// }

	// if doc_capa['publish_diagnostics'].as_map()['related_information'].bool() {
		// TODO: options for diagnostics
	// }

	// if doc_capa.completion.dynamic_registration {
		// server_capabilities.completion_provider.resolve_provider = false
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
		// 'textDocument/completion' { vls.completion(request.id, request.params) }
		// 'textDocument/hover' { vls.hover(request.id, request.params) }
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
	vls.doc = doc.Doc{
		table: vls.table
		prefs: vls.prefs
		checker: vls.checker
		pub_only: false
		with_head: false
		fmt: fmt.Fmt{
			indent: 0
			is_debug: false
			table: vls.table
		}
	}
	vls.start_loop()
}
