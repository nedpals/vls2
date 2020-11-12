module vls

import lsp
import json
import jsonrpc

struct JrpcResponse <T> {
	jsonrpc string = jsonrpc.version
	id      int
	result  T
}

// initialize sends the server capabilities to the client
fn (mut ls Vls) initialize(id int, params string) {
	mut capabilities := lsp.ServerCapabilities{
		text_document_sync: 1
		workspace_symbol_provider: true
		document_symbol_provider: true
		completion_provider: lsp.CompletionOptions{
			resolve_provider: false
		}
	}
	// TODO: use jsonrpc.ResponseMessage
	result := JrpcResponse<lsp.InitializeResult>{
		id: id
		result: lsp.InitializeResult{
			capabilities: capabilities
		}
	}
	ls.status = .initialized
	ls.send(json.encode(result))
}

// shutdown sets the state to shutdown but does not exit
fn (mut ls Vls) shutdown(params string) {
	ls.status = .shutdown
	unsafe {
		// ls.projects.free()
		ls.mod_import_paths.free()
		ls.import_graph.free()
		ls.mod_docs.free()
	}
}

// exit stops the process
fn (ls Vls) exit(params string) {
	// move exit to shutdown for now
	// == .shutdown => 0
	// != .shutdown => 1
	exit(int(ls.status != .shutdown))
}
