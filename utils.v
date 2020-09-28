module main

import net.urllib
import v.token
import lsp
import v.util

// https://github.com/microsoft/vscode-uri/blob/7c094c53581a8b1b7631fbc5c4265dea2beaf303/src/index.ts#L749
fn uri_file_str(f_path string) string {
	mut path := f_path
	mut authority := ''
	$if windows {
		path = path.replace('\\', '/')
	}
	if path[0] == `/` && path[1] == `/` {
		if idx := path[2..].index('/') {
			authority = path[2..(idx+2)]
			path = path[2..]

			if path.len == 0 {
				path = '/'
			}
		} else {
			authority = path[2..]
			path = '/'
		}
	}
	return 'file://${authority}${path}'
}

fn get_fspath_from_uri(str string) string {
	uri := urllib.parse(str) or {
		return ''
	}

	return uri.path
}

fn uri_file(f_path string) ?urllib.URL {
	str := uri_file_str(f_path)
	uri := urllib.parse(str) or {
		return error('invalid URI.')
	}
	return uri
}

fn (vls Vls) to_loc(file_path string, pos token.Position) lsp.Location {
	doc_uri := uri_file_str(file_path)
	range := vls.to_range(file_path, pos)
	return lsp.Location{
		uri: doc_uri
		range: range
	}
}

fn (vls Vls) to_pos(file_path string, pos token.Position) lsp.Position {
	source := vls.file_contents[file_path]
	p := util.imax(0, util.imin(source.len - 1, pos.pos))
	column := util.imax(0, pos.pos - p - 1)
	return lsp.Position{ line: pos.line_nr, character: util.imax(1, column+1) }
}

fn (vls Vls) to_range(file_path string, pos token.Position) lsp.Range {
	start_pos := vls.to_pos(file_path, pos)
	end_pos := { start_pos | character: start_pos.character + pos.len }
	range := lsp.Range{ start: start_pos, end: end_pos }
	return range
}