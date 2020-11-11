module main

import json
import jsonrpc
import os
import lsp
import v.parser
import v.scanner
// import v.ast
// import v.doc
import v.util
import time

fn (mut vls Vls) insert_file(uri string, text string, update bool) {
	doc_uri := fspath_to_uri(uri) or {
		emit_error(jsonrpc.invalid_request)
		return
	}
	project_dir, opened_filename := get_project_path(doc_uri.path)
	if project_dir !in vls.docs {
		vls.new_project(project_dir)
	}
	vls.projects[project_dir].nr_errors = 0
	mut project_file_paths := [doc_uri.path]
	if !update {
		project_files := os.ls(project_dir) or {
			emit_error(jsonrpc.invalid_request)
			return
		}
		project_file_paths = vls_prefs.should_compile_filtered_files(project_dir, project_files)
	}
	for file in project_file_paths {
		filename := os.base(file)
		if (vls.docs[project_dir].sources.len > 0 && filename in vls.docs[project_dir].sources) && filename != opened_filename {
			continue
		}
		mut raw_text := if text.len == 0 {
			vls.docs[project_dir].sources[filename]
		} else { 
			text
		}
		if filename != opened_filename {
			raw_text = os.read_file(file) or { '' }
		}
		raw_text = util.skip_bom(raw_text)

		// TODO: use a custom flow instead of parse_text or parse_file
		if !update {
			sc2 := scanner.new_scanner(raw_text, .toplevel_comments, vls_prefs)
			mut p := parser.Parser{
				scanner: sc2
				comments_mode: .toplevel_comments
				table: vls.table
				pref: vls_prefs
				scope: scope
				global_scope: global_scope
			}

			mut file_ast := p.parse()
			vls.process_mod_imports(mut file_ast)
			if filename in vls.asts[project_dir] {
				vls.asts[project_dir].delete(filename)
			}
			vls.asts[project_dir][filename] = file_ast
			vls.projects[project_dir].nr_errors += file_ast.errors.len
			if filename == opened_filename && filename !in vls.projects[project_dir].active_files {
				vls.projects[project_dir].active_files << filename
			}
		}

		if raw_text != vls.docs[project_dir].sources[filename] {
			// mut sc := scanner.new_scanner(raw_text, .skip_comments, vls_prefs)
			// sc.scan_all_tokens_in_buffer()
			// FIXME: Haven't pushed a relevant PR for scanner errors yet.
			// if !update {
			// 	vls.asts[project_dir][filename].warnings << sc.warnings
			// 	vls.asts[project_dir][filename].errors << sc.errors
			// }
			if filename in vls.docs[project_dir].sources {
				vls.docs[project_dir].sources.delete(filename)
			}
			// if filename in vls.tokens[project_dir] {
			// 	vls.tokens[project_dir].delete(filename)
			// }
			vls.docs[project_dir].sources[filename] = raw_text
			// vls.tokens[project_dir][filename] = sc.all_tokens
			// unsafe {
			// 	sc.all_tokens.free()
			// }
		}
		time.sleep_ms(10)
	}
	
	if !update {
		vls.import_modules()
		vls.document_project(mut vls.projects[project_dir])
		vls.publish_diagnostics(doc_uri.path)
	}
	unsafe {
		project_file_paths.free()
	}
}

// textDocument/didOpen
fn (mut vls Vls) open_file(raw string) {
	doc := json.decode(lsp.DidOpenTextDocumentParams, raw) or {
		emit_parse_error()
		return
	}
	vls.insert_file(doc.text_document.uri, doc.text_document.text, false)
	unsafe {
		doc.text_document.uri.free()
		doc.text_document.text.free()
	}
}

// textDocument/didChange
fn (mut vls Vls) change_file(raw string) {
	doc := json.decode(lsp.DidChangeTextDocumentParams, raw) or {
		emit_parse_error()
		return
	}
	vls.insert_file(doc.text_document.uri, doc.content_changes[0].text, true)
	unsafe {
		doc.text_document.uri.free()
		doc.content_changes.free()
	}
}

// textDocument/didSave
fn (mut vls Vls) save_file(raw string) {
	doc := json.decode(lsp.DidSaveTextDocumentParams, raw) or {
		emit_parse_error()
		return
	}
	vls.insert_file(doc.text_document.uri, '', false)
	unsafe {
		doc.text_document.uri.free()
	}
}

// textDocument/didClose
fn (mut vls Vls) close_file(raw string) {
	doc := json.decode(lsp.DidCloseTextDocumentParams, raw) or {
		emit_parse_error()
		return
	}
	doc_uri := fspath_to_uri(doc.text_document.uri) or {
		emit_error(jsonrpc.invalid_request)
		return
	}
	project_dir, filename := get_project_path_from_uri(doc.text_document.uri)
	vls.projects[project_dir].delete(filename)
	if vls.projects[project_dir].active_files.len == 0 {
		show_message(.info, 'VLS: Workspace closed.')
		vls.projects.delete(project_dir)
		vls.docs.delete(project_dir)
		vls.tokens.delete(project_dir)
		vls.asts.delete(project_dir)
	}
	vls.clear_diagnostics(doc_uri.path)
}

// workspace/didChangeWatchedFiles
fn (mut vls Vls) did_change_watched_files(raw string) {
	params := json.decode(lsp.DidChangeWatchedFilesParams, raw) or {
		emit_parse_error()
		return
	}

	for changed_file in params.changes {
		state := lsp.FileChangeType(changed_file.@type)
		match state {
			.created {
				fs_path := uri_str_to_fspath(changed_file.uri) or { '' }
				content := os.read_file(fs_path) or { '' }
				raw_payload := json.encode(lsp.DidOpenTextDocumentParams{
					text_document: lsp.TextDocumentItem{
						uri: changed_file.uri
						language_id: 'v'
						version: 1
						text: content
					}
				})
				vls.open_file(raw_payload)
			}
			.deleted {
				raw_payload := json.encode(lsp.DidCloseTextDocumentParams{
					text_document: lsp.TextDocumentIdentifier{
						uri: changed_file.uri
					}
				})
				vls.close_file(raw_payload)
			}
			.changed { continue }
		}
	}
}

fn (mut vls Vls) document_project(mut prj Project) {
	if prj.nr_errors > 0 { return }
	file_asts := file_asts_arr(vls.asts[prj.path])
	vls.docs[prj.path].checker.check_files(file_asts)
	vls.docs[prj.path].file_asts(file_asts) or {
		return
	}
	contents := vls.docs[prj.path].contents.arr()
	vls.projects[prj.path].insert('', { 
		symbols: provide_symbols(contents) 
	})
	// show_message(.info, vls.projects[prj.path].cached_symbols.len.str())
	unsafe {
		file_asts.free()
	}
}