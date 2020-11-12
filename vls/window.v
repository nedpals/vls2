module vls

import lsp
import json
import jsonrpc

struct JrpcNotification <T> {
	jsonrpc string = jsonrpc.version
	method  string
	params  T
}

// log_message sends a window/logMessage notification to the client
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

// show_message sends a window/showMessage notification to the client
fn (ls Vls) show_message(message string, typ lsp.MessageType) {
	result := JrpcNotification<lsp.ShowMessageParams>{
		method: 'window/showMessage'
		params: lsp.ShowMessageParams{
			@type: typ
			message: message
		}
	}
	ls.send(json.encode(result))
}

fn (ls Vls) show_message_request(message string, actions []lsp.MessageActionItem, typ lsp.MessageType) {
	result := JrpcNotification<lsp.ShowMessageRequestParams>{
		method: 'window/showMessageRequest'
		params: lsp.ShowMessageRequestParams{
			@type: typ
			message: message
			actions: actions
		}
	}
	ls.send(json.encode(result))
}
