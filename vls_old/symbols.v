module vls_old

import lsp
import v.doc
import json

fn provide_symbols(doc_nodes []doc.DocNode) []lsp.SymbolInformation {
	mut symbols := []lsp.SymbolInformation{}
	for	node in doc_nodes {
		if node.kind == .const_group {
			symbols << provide_symbols(node.children)
			continue
		}
		if node.kind in [.enum_field, .struct_field, .variable, .constant] || node.name.len < 1 {
			continue
		}
		sym_kind := match node.kind {
			.constant {
				lsp.SymbolKind.constant
			}
			.enum_ {
				lsp.SymbolKind.enum_
			}
			.interface_ {
				lsp.SymbolKind.interface_
			}
			.struct_ {
				lsp.SymbolKind.struct_
			}
			.typedef {
				lsp.SymbolKind.type_parameter
			}
			.function,
			.method {
				lsp.SymbolKind.function
			}
			else {
				lsp.SymbolKind.null
			}
		}
		symbols << lsp.SymbolInformation{
			name: if node.kind == .method { '${node.parent_name}.${node.name}' } else { node.name }
			kind: sym_kind
			deprecated: false
			location: doc_pos_to_lsp_loc(node.file_path, node.pos)
			container_name: node.parent_name
		}
	}
	return symbols
}

// workspace/symbol
fn (mut vls Vls) workspace_symbol(id int, raw string) {
	mut symbols := []lsp.SymbolInformation{}
	for _, prj in vls.projects {
		symbols << prj.cached_symbols
	}
	return result_message(JrpcResponse<[]lsp.SymbolInformation>{
		id: id
		result: symbols
	})
}

// textDocument/documentSymbol
fn (mut vls Vls) document_symbol(id int, raw string) string {
	params := json.decode(lsp.DocumentSymbolParams, raw) or {
		emit_parse_error_message()
		return
	}
	fspath := uri_str_to_fspath(params.text_document.uri) or {
		cancel_request(id)
		return
	}
	dir, _ := get_project_path(fspath)
	return result_message(JrpcResponse<[]lsp.SymbolInformation>{
		id: id
		result: vls.projects[dir].cached_symbols
	})
}