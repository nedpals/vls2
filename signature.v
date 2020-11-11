module main

// import json
// import lsp

fn (vls Vls) signature_help(id int, params string) {
	// TODO: broken
	// info := json.decode(lsp.SignatureHelpParams, params) or {
	// 	emit_parse_error()
	// 	return
	// }

	// pos := info.position
	// tok, tok_pos := vls.search_token(pos.line, pos.character, fs_path) or {
	// 	cancel_request(id)
	// 	return
	// }

	// respond(JrpcResponse<lsp.SignatureHelp>{
	// 	id: id
	// 	result: lsp.SignatureHelp{
	// 		signatures: []lsp.SignatureInformation{}
	// 		active_signature: 0
	// 		active_parameter: 0
	// 	}
	// })
}