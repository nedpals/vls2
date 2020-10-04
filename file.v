module main

import json
import jsonrpc
import os
import lsp
import v.parser
import v.ast
import time

fn (mut vls Vls) insert_file(uri string) {
	doc_uri := uri_file(uri) or {
		emit_error(jsonrpc.invalid_request)
		return
	}

	base := os.dir(doc_uri.path)
	project_files := os.ls(base) or {
		emit_error(jsonrpc.invalid_request)
		return
	}

	v_files := vls.prefs.should_compile_filtered_files(base, project_files)
	global_scope := &ast.Scope{ parent: 0 }

	for file in v_files {
		file_ast := parser.parse_file(file, vls.table, .skip_comments, vls.prefs, global_scope)
		vls.files[file] = file_ast

		// copied from util.read_file
		mut raw_text := os.read_file(file) or { '' }
		if raw_text.len >= 3 {
			unsafe {
				c_text := raw_text.str
				if c_text[0] == 0xEF && c_text[1] == 0xBB && c_text[2] == 0xBF {
					// skip three BOM bytes
					offset_from_begin := 3
					raw_text = tos(c_text[offset_from_begin], vstrlen(c_text) - offset_from_begin)
				}
			}
		}
		vls.file_contents[file] = raw_text
		vls.doc_nodes[file] = vls.doc.generate_from_ast(file_ast, file_ast.mod.name)
		vls.doc.fmt.mod2alias = map[string]string{}
		time.sleep_ms(10)
	}

	vls.publish_diagnostics(doc_uri.path)
}

// textDocument/didOpen
fn (mut vls Vls) open_file(id int, raw string) {
	doc := json.decode(lsp.DidOpenTextDocumentParams, raw) or {
		emit_parse_error()
		return
	}
	
	vls.insert_file(doc.text_document.uri)
}

// textDocument/didSave
fn (mut vls Vls) save_file(id int, raw string) {
	doc := json.decode(lsp.DidSaveTextDocumentParams, raw) or {
		emit_parse_error()
		return
	}

	vls.insert_file(doc.text_document.uri)
}

// textDocument/didClose
fn (mut vls Vls) close_file(id int, raw string) {
	doc := json.decode(lsp.DidCloseTextDocumentParams, raw) or {
		emit_parse_error()
		return
	}

// TODO: close file if the entire workspace folder has closed
	doc_uri := uri_file(doc.text_document.uri) or {
		emit_error(jsonrpc.invalid_request)
		return
	}
	vls.clear_diagnostics(doc_uri.path)
}