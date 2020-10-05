module main

// import jsonrpc
import json
import lsp
// import v.ast
import v.checker
import v.errors

fn (vls Vls) to_diag_warning(w errors.Warning) lsp.Diagnostic {
	w_range := vls.to_range(w.file_path, w.pos)
	return lsp.Diagnostic{
		range: w_range
		severity: 2
		source: w.reporter.str()
		message: w.message
		related_information: [
			lsp.DiagnosticRelatedInformation{
				location: lsp.Location{
					uri: uri_file_str(w.file_path)
					range: w_range
				}
				message: ''
			},
		]
	}
}

fn (vls Vls) to_diag_error(e errors.Error) lsp.Diagnostic {
	e_range := vls.to_range(e.file_path, e.pos)
	return lsp.Diagnostic{
		range: e_range
		severity: 1
		source: e.reporter.str()
		message: e.message
		related_information: [
			lsp.DiagnosticRelatedInformation{
				location: lsp.Location{
					uri: uri_file_str(e.file_path)
					range: e_range
				}
				message: ''
			},
		]
	}
}

// textDocument/publishDiagnostics
// notification
fn (mut vls Vls) publish_diagnostics(file_path string) {
	vls.checker.errors = []errors.Error{}
	vls.checker.warnings = []errors.Warning{}
	mut diag := []lsp.Diagnostic{}
	file := vls.files[file_path]
	vls.checker.check(file)
	for w in file.warnings {
		diag << vls.to_diag_warning(w)
	}
	for e in file.errors {
		diag << vls.to_diag_error(e)
	}
	for w in vls.checker.warnings {
		diag << vls.to_diag_warning(w)
	}
	for e in vls.checker.errors {
		diag << vls.to_diag_error(e)
	}
	result := JrpcNotification<lsp.PublishDiagnosticsParams>{
		method: 'textDocument/publishDiagnostics'
		params: lsp.PublishDiagnosticsParams{
			uri: uri_file_str(file.path)
			diagnostics: diag
		}
	}
	respond(json.encode(result))
}

fn (mut vls Vls) clear_diagnostics(file_path string) {
	result := JrpcNotification<lsp.PublishDiagnosticsParams>{
		method: 'textDocument/publishDiagnostics'
		params: lsp.PublishDiagnosticsParams{
			uri: uri_file_str(file_path)
			diagnostics: []lsp.Diagnostic{}
		}
	}

	respond(json.encode(result))
}
