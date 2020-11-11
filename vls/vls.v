module vls

import v.table
import v.doc
import v.token
import v.ast
import json
import jsonrpc
import strings

const (
	content_length = 'Content-Length: '
)

pub struct Vls {
mut:
	table            &table.Table = table.new_table()
	status           ServerStatus = .initializing
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
}

type SendFn = fn ( string)

pub fn (mut ls Vls) execute(payload string, send SendFn) {
	request := json.decode(jsonrpc.Request, payload) or {
		send(new_error(jsonrpc.parse_error))
		return
	}
	if request.method != 'exit' && ls.status == .shutdown {
		send(new_error(jsonrpc.invalid_request))
	}
	match request.method {
		'initialize' {
			ls.initialize(request.id, request.params, send)
		}
		'initialized' {
			ls.status = .initialized
		}
		'shutdown' {
			ls.shutdown(request.id, request.params, send)
		}
		'exit' {
			ls.exit(request.id, request.params, send)
		}
		else {
			if ls.status != .initialized {
				send(new_error(jsonrpc.server_not_initialized))
			}
		}
	}
}

// status returns the current server status
pub fn (ls Vls) status() ServerStatus {
	return ls.status
}

fn C.fgetc(stream byteptr) int

// start_loop starts an endless loop which waits for stdin and prints responses to the stdout
pub fn (mut ls Vls) start_loop() {
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
		ls.execute(payload[1..], fn (res string) {
			// print to stdout
			print(res)
		})
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
	initializing
	initialized
	shutdown
}
