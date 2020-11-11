module vls_old

import json
import lsp
import v.token
import v.doc

fn (vls Vls) search_token(line int, col int, fs_path string) ?(token.Token, doc.DocPos) {
	project_path, filename := get_project_path(fs_path)
	tokens := vls.tokens[project_path][filename]

	for tok in tokens {
		if tok.kind == .comment { continue }
		tok_pos := token.Position{ pos: tok.pos, len: tok.len, line_nr: tok.line_nr }
		pos := vls.to_doc_pos(fs_path, tok_pos)
		if pos.line == line && (col >= pos.col && col <= (pos.col+pos.len-1)) {
			return tok, pos
		}
	}

	return error('token not found')
}

fn (mut vls Vls) hover(id int, raw string) string {
	params := json.decode(lsp.HoverParams, raw) or {
		emit_parse_error_message()
		return
	}
	fs_path := uri_str_to_fspath(params.text_document.uri) or {
		cancel_request(id)
		return
	}
	// dir, name := get_project_path(fs_path)
	pos := params.position
	// file_ast := vls.asts[dir][name]
	tok, tok_doc_pos := vls.search_token(pos.line, pos.character, fs_path) or {
		cancel_request(id)
		return
	}
	// found_ast, doc_pos := vls.get_ast_by_pos(tok_doc_pos.line-1, tok_doc_pos.col+tok_doc_pos.len, fs_path, file_ast.stmts.map(AstNode(it))) or {
	// 	if tok.lit.len > 0 {
	range := doc_pos_to_lsp_range(tok_doc_pos)
	return result_message(JrpcResponse<lsp.Hover>{
		id: id
		result: lsp.Hover{
			contents: lsp.MarkedString{
				language: 'v'
				value: tok.lit
			}
			range: range
		}
	})
	// 	} else {
	// 		cancel_request(id)
	// 	}
	// 	return
	// }
	// range := doc_pos_to_lsp_range({doc_pos | line: doc_pos.line + 1})
	// respond(json.encode(JrpcResponse<lsp.Hover>{
	// 	id: id
	// 	result: lsp.Hover{
	// 		contents: lsp.MarkedString{
	// 			language: 'plaintext'
	// 			value: typeof(found_ast)
	// 		}
	// 		range: range
	// 	}
	// }))
}