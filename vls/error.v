module vls

import jsonrpc
import json

// with error
struct JrpcResponse2<T> {
	jsonrpc string = jsonrpc.version
	id int
	error jsonrpc.ResponseError
	result T
}

[inline]
fn new_error(code int) string {
	err := JrpcResponse2<string>{
		error: jsonrpc.new_response_error(code)
	}
	return json.encode(err)
}
