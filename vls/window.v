module vls

import lsp
import json
import jsonrpc

struct JrpcNotification <T> {
	jsonrpc string = jsonrpc.version
	method  string
	params  T
}

fn (ls Vls) log_message(message string, typ lsp.MessageType) {
	result := JrpcNotification<lsp.LogMessageParams>{
		method: 'window/logMessage'
		params: lsp.LogMessageParams{
			@type: typ
			message: message
		}
	}
	ls.send(json.encode(result))
}
