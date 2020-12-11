module vls

import v.table
import v.doc
import v.token
import v.ast
import json
import jsonrpc
import strings
import net
import io

const (
	content_length = 'Content-Length: '
)

pub enum ConnectionType {
	tcp
	stdio
}

pub struct Vls {
mut:
	table            &table.Table = table.new_table()
	// imports
	import_graph     map[string][]string
	mod_import_paths map[string]string
	mod_docs         map[string]doc.Doc
	// directory -> file name
	// projects         map[string]Project
	docs             map[string]doc.Doc
	tokens           map[string]map[string][]token.Token
	asts             map[string]map[string]ast.File
	current_file     string
	root_path        string
	connection_type  ConnectionType = .stdio
	tcp_conn				 &net.TcpConn = 0
pub mut:
	// TODO: replace with io.Writer
	// send             fn (string) = fn (res string) {}
	status           ServerStatus = .off
	response         string
	test_mode       bool
}

pub fn (mut ls Vls) execute(payload string) string {
	request := json.decode(jsonrpc.Request, payload) or {
		return new_error(jsonrpc.parse_error)
	}
	if request.method != 'exit' && ls.status == .shutdown {
		return new_error(jsonrpc.invalid_request)
	}
	if request.method != 'initialize' && ls.status != .initialized {
		return new_error(jsonrpc.server_not_initialized)
	}
	match request.method {
		'initialize' {
			return ls.initialize(request.id, request.params)
		}
		'initialized' {} // does nothing currently
		'shutdown' {
			ls.shutdown(request.params)
		}
		'exit' {
			ls.exit(request.params)
		}
		'textDocument/didOpen' {
			return ls.did_open(request.id, request.params)
		}
		'textDocument/didChange' {
			return ls.did_change(request.id, request.params)
		}
		else {
			if ls.status != .initialized {
				return new_error(jsonrpc.server_not_initialized)
			}
		}
	}

	return ''
}

fn C.fgetc(stream byteptr) int

// start_server starts an endless loop which waits for the request data and prints the responses to the desired connection type
pub fn (mut ls Vls) start_server() {
	if ls.connection_type == .tcp {
		// TODO: custom TCP port
		server := net.listen_tcp(6220) or { panic(err) }

		for {
			mut conn := server.accept() or {
				server.close() or { }
				panic(err)
			}

			vls.tcp_conn = &conn

			mut reader := io.new_buffered_reader(reader: io.make_reader(con))
			first_line := reader.read_line() or {
				ls.send(new_error(jsonrpc.invalid_request))
				return
			}
			request_parts := first_line.split(' ')
			if request_parts.len != 3 {
				ls.send(new_error(jsonrpc.invalid_request))
				return
			}
			urlpath := request_parts[1]
			// filename := if urlpath == '/' { ctx.default_filename.trim_left('/') } else { urlpath.trim_left('/') }
			// if ctx.docs[filename].len == 0 {
				
			// 	return
			// }

			conn.close() or { eprintln('error closing the connection: $err') }
		}

		return
	}

	for {
		first_line := get_raw_input()
		if first_line.len < 1 || !first_line.starts_with(content_length) {
			continue
		}
		mut buf := strings.new_builder(1)
		mut conlen := first_line[content_length.len..].int()
		$if !windows { conlen++ }
		for conlen > 0 {
			c := C.fgetc(C.stdin)
			$if !windows {
				if c == 10 { continue }
			}
			buf.write_b(byte(c))
			conlen--
		}
		payload := buf.str()
		ls.send(ls.execute(payload[1..]))
		unsafe { buf.free() }
	}
}

fn get_raw_input() string {
	eof := C.EOF
	mut buf := strings.new_builder(200)
	for {
		c := C.fgetc(C.stdin)
		chr := byte(c)
		if buf.len > 2 && (c == eof || chr in [`\r`, `\n`]) {
			break
		}
		buf.write_b(chr)
	}
	return buf.str()
}

pub enum ServerStatus {
	off
	initialized
	shutdown
}

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
