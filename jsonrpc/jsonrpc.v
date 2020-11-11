module jsonrpc

pub const (
	version                = '2.0'
	parse_error            = -32700
	invalid_request        = -32600
	method_not_found       = -32601
	invalid_params         = -32602
	internal_error         = -32693
	server_error_start     = -32099
	server_error_end       = -32600
	server_not_initialized = -32002
	unknown_error          = -32001
)

pub struct Request {
pub mut:
	jsonrpc string = version
	id      int
	method  string
	params  string [raw]
}

pub struct Response <T> {
pub:
	jsonrpc string = version
	id      int
	error   ResponseError
	result  T
}

struct ResponseError {
mut:
	code    int
	message string
	data    string
}

pub fn new_response_error(err_code int) ResponseError {
	return ResponseError{
		code: err_code
		message: err_message(err_code)
	}
}

pub fn err_message(err_code int) string {
	// can't use error consts in match
	if err_code == parse_error {
		return 'Invalid JSON.'
	} else if err_code == invalid_params {
		return 'Invalid params.'
	} else if err_code == invalid_request {
		return 'Invalid request.'
	} else if err_code == method_not_found {
		return 'Method not found.'
	} else if err_code == server_error_end {
		return 'An error occurred while stopping the server.'
	} else if err_code == server_error_start {
		return 'An error occurred while starting the server.'
	} else if err_code == server_not_initialized {
		return 'Server not yet initialized.'
	}
	return 'Unknown error.'
}
