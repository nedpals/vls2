module vls_old

import lsp
import v.doc

fn completion_items(doc_nodes []doc.DocNode) []lsp.CompletionItem {
	mut items := []lsp.CompletionItem{}

	for node in doc_nodes {
		if node.kind in [.const_group, .enum_] {
			items << completion_items(node.children)
			continue
		}
		if node.name == 'main' || node.name.len < 1 {
			continue
		}

		kind := match node.kind {
			.constant {
				lsp.CompletionItemKind.constant
			}
			.enum_field {
				lsp.CompletionItemKind.enum_member
			}
			.interface_ {
				lsp.CompletionItemKind.interface_
			}
			.struct_ {
				lsp.CompletionItemKind.struct_
			}
			.typedef {
				lsp.CompletionItemKind.type_parameter
			}
			.function,
			.method {
				lsp.CompletionItemKind.function
			}
			.variable {
				lsp.CompletionItemKind.variable
			}
			else {
				lsp.CompletionItemKind.field
			}
		}
		items << lsp.CompletionItem{
			label: if node.kind == .enum_field { '${node.parent_name}.${node.name}' } else { node.name }
			kind: kind
			detail: node.return_type
			documentation: lsp.MarkupContent{'markdown', node.content}
			deprecated: node.deprecated
		}
	}

	return items
}

/*
fn (mut vls Vls) completion(id int, raw string) string {
	// use position for now
	params := json.decode(lsp.CompletionParams, raw) or {
		return parse_error()
	}
	// ctx := params.context
	pos := params.position
	fs_path := uri_str_to_fspath(params.text_document.uri) or {
		cancel_request(id)
		return
	}
	mut items := []lsp.CompletionItem{}
	dir, filename := get_project_path(fs_path)
	// vls.search_token(pos.line, pos.character, fs_path) or {
	// 	cancel_request(id)
	// 	return
	// }

	if vls.projects[dir].nr_errors == 0 {
		file_ast := vls.asts[dir][filename]
		offset := vls.compute_offset(fs_path, pos.line, pos.character)
		scoped := vls.docs[dir].file_ast_with_pos(file_ast, offset)
		vls.docs[dir].scoped_contents = scoped
		// if vls.saved_fspath != fs_path {
		items << completion_items(vls.docs[dir].scoped_contents.arr())
		items << completion_items(vls.docs[dir].contents.arr())
		mut imports := ['builtin']
		imports << file_ast.imports.map(it.mod)

		for idx, mod in imports {
			mod_doc_node := vls.mod_docs[mod].contents.arr()
			mut mod_items := completion_items(mod_doc_node)
			
			if mod != 'builtin' {
				imp := file_ast.imports[idx-1]
				prefix := if imp.alias.len > 0 { imp.alias } else { imp.mod }

				for i, mod_item in mod_items {
					mod_items[i].label = '${prefix}.${mod_item.label}'
				}
			}

			items << mod_items
			vls.projects[dir].insert('', { completion: items })
		}
	} else {
		items = vls.projects[dir].cached_completion
	}

	result := JrpcResponse<[]lsp.CompletionItem>{
		id: id
		result: items
	}
	return result_message(result)
}*/