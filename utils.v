module main

import net.urllib
import v.token
import lsp
import v.util
import v.doc
import os

// PATH CONVERSION
fn get_project_path(fspath string) (string, string) {
	project_dir := os.dir(fspath)
	filename := os.base(fspath)
	return project_dir, filename
}

fn get_project_path_from_uri(uristr string) (string, string) {
	fspath := uri_str_to_fspath(uristr) or { '' }
	return get_project_path(fspath)
}

// https://github.com/microsoft/vscode-uri/blob/7c094c53581a8b1b7631fbc5c4265dea2beaf303/src/index.ts#L749
fn fspath_to_uri_str(f_path string) string {
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

fn fspath_to_uri(f_path string) ?urllib.URL {
	uri := urllib.parse(fspath_to_uri_str(f_path)) or {
		return error('invalid URI.')
	}
	return uri
}

fn uri_str_to_fspath(uris string) ?string {
	uri := urllib.parse(uris) or {
		return uris
	}
	fs_path := uri.path
	if fs_path.len == 0 {
		return error('uri invalid')
	}
	return fs_path
}

// OFFSET CONVERSION
fn (vls Vls) compute_offset(fs_path string, line int, col int) int {
	dir, name := get_project_path(fs_path)
	text := vls.docs[dir].sources[name]
	lines := text.split_into_lines()
	mut offset := 0
	for i, ln in lines {
		if i == line {
			if col > ln.len {
				return -1
			}
			if ln.len == 0 {
				offset++
				break
			}
			offset += col
			break
		} else {
			offset += ln.len+1
		}
	}
	unsafe {
		lines.free()
	}
	return offset
}

// POSITION / LOCATION CONVERSION
fn doc_pos_to_lsp_loc(file_path string, dp doc.DocPos) lsp.Location {
	doc_uri := fspath_to_uri_str(file_path)
	range := doc_pos_to_lsp_range(dp)
	return lsp.Location{
		uri: doc_uri
		range: range
	}
}

fn doc_pos_to_lsp_range(dp doc.DocPos) lsp.Range {
	start_pos := lsp.Position{
		line: dp.line
		character: dp.col-1
	}
	end_pos := { start_pos | character: start_pos.character + dp.len }
	return lsp.Range{ start: start_pos, end: end_pos }
}

fn (vls Vls) to_loc(file_path string, pos token.Position) lsp.Location {
	doc_uri := fspath_to_uri_str(file_path)
	dir, name := get_project_path(file_path)
	source := vls.docs[dir].sources[name]
	range := to_range(source, pos)
	return lsp.Location{
		uri: doc_uri
		range: range
	}
}

fn (vls Vls) to_doc_pos(file_path string, pos token.Position) doc.DocPos {
	dir, name := get_project_path(file_path)
	source := vls.docs[dir].sources[name]
	p := util.imax(0, util.imin(source.len - 1, pos.pos))
	column := util.imax(0, pos.pos - get_column(source, p))
	return doc.DocPos{
		line: pos.line_nr-1
		col: util.imax(1, column - 1)
		len: pos.len
	}
}

fn (vls Vls) to_range(file_path string, pos token.Position) lsp.Range {
	dir, name := get_project_path(file_path)
	source := vls.docs[dir].sources[name]
	return to_range(source, pos)
}

fn to_pos(source string, pos token.Position) lsp.Position {
	p := util.imax(0, util.imin(source.len - 1, pos.pos))
	column := util.imax(0, pos.pos - get_column(source, p)) - 1
	return lsp.Position{ line: pos.line_nr, character: util.imax(1, column) - 1 }
}

fn to_range(source string, pos token.Position) lsp.Range {
	start_pos := to_pos(source, pos)
	end_pos := { start_pos | character: start_pos.character + pos.len }
	return lsp.Range{ start: start_pos, end: end_pos }
}

fn get_column(source string, initp int) int {
	mut p := initp
	if source.len > 0 {
		for ; p >= 0; p-- {
			if source[p] == `\r` || source[p] == `\n` {
				break
			}
		}
	}
	return p - 1
}