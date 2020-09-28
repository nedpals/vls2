module main

import jsonrpc
import lsp
import json

fn C.fgetc(stream byteptr) int

const (
	content_length = 'Content-Length: '
)

// TODO: have a way to autogenerate ID
// for requests that have an id
struct JrpcRequest2<T> {
pub mut:
  jsonrpc string = jsonrpc.version
  id int
  method string
  params T
}

// for requests without an id
struct JrpcRequest3<T> {
pub mut:
  jsonrpc string = jsonrpc.version
  method string
  params T
}

struct JrpcResponse<T> {
	jsonrpc string = jsonrpc.version
	id int
	result T
}

// with error
struct JrpcResponse2<T> {
	jsonrpc string = jsonrpc.version
	id int
	error jsonrpc.ResponseError
	result T
}

fn get_raw_input() string {
	eof := C.EOF
	mut c := -2
	mut buf := ''
	for {
		c = C.fgetc(C.stdin)
		chr := byte(c)
		if buf.len > 2 && (c == eof || chr in [`\r`, `\n`]) {
			return buf
		}
		buf += chr.str()
	}
	return buf
}

[inline]
fn respond(data string) {
	print('Content-Length: ${data.len}\r\n\r\n$data')
}

[inline]
fn emit_error(err_code int) {
	err := JrpcResponse2<string>{
		error: jsonrpc.send_error_code(err_code)
	}
	respond(json.encode(err))
}

[inline]
fn emit_parse_error() {
	emit_error(jsonrpc.parse_error)
}

[inline]
fn show_message(typ lsp.MessageType, message string) {
	respond(json.encode(JrpcRequest3<lsp.ShowMessageParams>{
		method: 'window/showMessage'
		params: lsp.ShowMessageParams{typ, message}
	}))
}

[inline]
fn log_message(typ lsp.MessageType, message string) {
	respond(json.encode(JrpcRequest3<lsp.LogMessageParams>{
		method: 'window/logMessage'
		params: lsp.LogMessageParams{typ, message}
	}))
}

[inline]
fn show_message_request(typ lsp.MessageType, message string, actions []lsp.MessageActionItem) {
	respond(json.encode(JrpcRequest3<lsp.ShowMessageRequestParams>{
		method: 'window/showMessage'
		params: lsp.ShowMessageRequestParams{typ, message, actions}
	}))
}