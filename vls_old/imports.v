module vls_old

import v.ast
import v.errors
import v.doc

// FIXME:

// IMPORT GRAPH
// vls.import_graph will keep track of the list of modules as dependencies
// used by the respective files (or text documents in LSP terms). Once
// there is no file left that is dependent to a specific module, the module
// will be removed safely into the language server.
fn (mut vls Vls) process_mod_imports(mut file_ast ast.File) {
	if file_ast.errors.len > 0 { return }
	mut imports := file_ast.imports.map(it.mod)
	if 'builtin' !in vls.import_graph {
		imports << 'builtin'
	}
	for idx, imprt in imports {
		if file_ast.path in vls.import_graph[imprt] {
			continue
		}

		mod_path := doc.lookup_module(imprt) or {
			if imprt != 'builtin' {
				file_ast.errors << errors.Error{
					message: err
					file_path: file_ast.path
					pos: file_ast.imports[idx].pos
					reporter: .checker
				}
				vls.clear_diagnostics(file_ast.path)
				vls.publish_diagnostics(file_ast.path)
			}
			continue
		}

		vls.import_graph[imprt] << [file_ast.path]
		vls.mod_import_paths[imprt] = mod_path
	}
}

fn (mut vls Vls) import_modules() {
	for mod_name, mod_path in vls.mod_import_paths {
		if mod_name in vls.mod_docs {
			continue
		}

		// temp fix for now
		mod_doc := doc.generate(mod_path, true, true) or {
			continue
		}

		vls.mod_docs[mod_name] = mod_doc
	}
}