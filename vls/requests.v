module vls

import lsp
import jsonrpc
import json

struct JrpcResponse <T> {
	jsonrpc string = jsonrpc.version
	id      int
	result  T
}

// initialize sends the server capabilities to the client
fn (ls Vls) initialize(id int, params string, send SendFn) {
	mut capabilities := lsp.ServerCapabilities{
		text_document_sync: 1
		workspace_symbol_provider: true
		document_symbol_provider: true
		completion_provider: lsp.CompletionOptions{
			resolve_provider: false
		}
	}
	result := JrpcResponse<lsp.InitializeResult>{
		id: id
		result: lsp.InitializeResult{
			capabilities: capabilities
		}
	}
	send(json.encode(result))
}

// shutdown sets the state to shutdown but does not exit
fn (mut ls Vls) shutdown(id int, params string, send SendFn) {
	ls.status = .shutdown
	unsafe {
		// ls.projects.free()
		ls.mod_import_paths.free()
		ls.import_graph.free()
		ls.mod_docs.free()
	}
}

// exit stops the process
fn (ls Vls) exit(id int, params string, send SendFn) {
	// move exit to shutdown for now
	// == .shutdown => 0
	// != .shutdown => 1
	exit(int(ls.status != .shutdown))
}
