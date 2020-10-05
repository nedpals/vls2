module main

import lsp
import v.doc
import v.ast
import json

fn doc_pos_to_lsp_loc(file_path string, dp doc.DocPos) lsp.Location {
	doc_uri := uri_file_str(file_path)
	range := doc_pos_to_lsp_range(dp)
	return lsp.Location{
		uri: doc_uri
		range: range
	}
}

fn doc_pos_to_lsp_pos(dp doc.DocPos) lsp.Position {
	return lsp.Position{ 
		line: dp.line-1
		character: dp.col 
	}
}

fn doc_pos_to_lsp_range(dp doc.DocPos) lsp.Range {
	start_pos := doc_pos_to_lsp_pos(dp)
	end_pos := { start_pos | character: start_pos.character + dp.len }
	return lsp.Range{ start: start_pos, end: end_pos }
}

fn (vls Vls) provide_symbols(doc_nodes []doc.DocNode) []lsp.SymbolInformation {
	mut symbols := []lsp.SymbolInformation{}
	for node in doc_nodes {
		sym_kind := match node.attrs['category'] {
			'Constants' {
				lsp.SymbolKind.constant
			}
			'Enums' {
				lsp.SymbolKind.@enum
			}
			'Interfaces' {
				lsp.SymbolKind.@interface
			}
			'Structs' {
				lsp.SymbolKind.@struct
			}
			'Typedefs' {
				lsp.SymbolKind.type_parameter
			}
			'Functions',
			'Methods' {
				lsp.SymbolKind.function
			}
			else {
				lsp.SymbolKind.null
			}
		}

		symbols << lsp.SymbolInformation{
			name: node.name
			kind: sym_kind
			deprecated: false
			location: doc_pos_to_lsp_loc(node.file_path, node.pos)
			container_name: 'test'
		}
			// ast.StructDecl {
			// 	symbols << lsp.DocumentSymbol{
			// 		name: stmt.name
			// 		detail: ''
			// 		kind: .@struct
			// 		deprecated: stmt.attrs.contains('deprecated')
			// 		range: range
			// 		selection_range: range
			// 	}
			// }
			// ast.AssignStmt {
			// 	for _ in stmt.left {
			// 		symbols << lsp.DocumentSymbol{
			// 			name: ''
			// 			detail: ''
			// 			kind: .variable
			// 			deprecated: false
			// 			range: range
			// 			selection_range: range
			// 		}
			// 	}
			// }
			// ast.FnDecl {
			// 	mut sym := lsp.DocumentSymbol{
			// 		name: stmt.name
			// 		detail: ''
			// 		kind: .function
			// 		deprecated: stmt.is_deprecated
			// 		range: range
			// 		selection_range: range
			// 	}
			// 	// receiver
			// 	if stmt.receiver.name.len > 0 {
			// 		rec_pos := vls.to_range(file_path, stmt.receiver_pos)
			// 		sym.children << lsp.DocumentSymbol{
			// 			name: stmt.receiver.name
			// 			detail: ''
			// 			kind: .variable
			// 			deprecated: false
			// 			range: rec_pos
			// 			selection_range: rec_pos
			// 		}
			// 	}
			// 	for arg in stmt.params {
			// 		sym.children << lsp.DocumentSymbol{
			// 			name: arg.name
			// 			detail: ''
			// 			kind: .variable
			// 			deprecated: false
			// 			range: range
			// 			selection_range: range
			// 		}
			// 	}
			// 	sym.children << vls.provide_symbols(file_path, stmt.stmts)
			// 	symbols << sym
			// }
			// else {
			// 	continue
			// }
	}
	return symbols
}

// workspace/symbol
fn (mut vls Vls) workspace_symbol(id int, raw string) {
	// _ := json.decode(lsp.WorkspaceSymbolParams, raw) or {
	// 	emit_parse_error()
	// 	return
	// }
	mut symbols := []lsp.SymbolInformation{}
	for _, doc_nodes in vls.doc_nodes {
		symbols << vls.provide_symbols(doc_nodes)
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
	doc_nodes := vls.doc_nodes[fs_path]
	symbols := vls.provide_symbols(doc_nodes)
	respond(json.encode(JrpcResponse<[]lsp.SymbolInformation>{
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
