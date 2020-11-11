module vls_old
/*
import json
import lsp
import v.errors


fn diagnose_warning(file_path string, source string, w errors.Warning) lsp.Diagnostic {
	w_range := to_range(source, w.pos)
	return lsp.Diagnostic{
		range: w_range
		severity: 2
		source: w.reporter.str()
		message: w.message
		related_information: [
			lsp.DiagnosticRelatedInformation{
				location: lsp.Location{
					uri: fspath_to_uri_str(file_path)
					range: w_range
				}
			},
		]
	}
}

fn diagnose_error(file_path string, source string, e errors.Error) lsp.Diagnostic {
	e_range := to_range(source, e.pos)
	return lsp.Diagnostic{
		range: e_range
		severity: 1
		source: e.reporter.str()
		message: e.message
		related_information: [
			lsp.DiagnosticRelatedInformation{
				location: lsp.Location{
					uri: fspath_to_uri_str(file_path)
					range: e_range
				}
				message: ''
			},
		]
	}
}

// textDocument/publishDiagnostics
// notification
fn (mut vls Vls) publish_diagnostics(file_path string) string {
	mut diag := []lsp.Diagnostic{}
	dir, name := get_project_path(file_path)
	file := vls.asts[dir][name]
	source := vls.docs[dir].sources[name]
	for w in file.warnings {
		diag << diagnose_warning(file_path, source, w)
	}
	for e in file.errors {
		diag << diagnose_error(file_path, source, e)
	}
	result := JrpcNotification<lsp.PublishDiagnosticsParams>{
		method: 'textDocument/publishDiagnostics'
		params: lsp.PublishDiagnosticsParams{
			uri: fspath_to_uri_str(file_path)
			diagnostics: diag
		}
	}
	resp := result_message(result)
	unsafe {
		diag.free()
	}
	return resp
}

fn (mut vls Vls) clear_diagnostics(file_path string) string {
	result := JrpcNotification<lsp.PublishDiagnosticsParams>{
		method: 'textDocument/publishDiagnostics'
		params: lsp.PublishDiagnosticsParams{
			uri: fspath_to_uri_str(file_path)
			diagnostics: []lsp.Diagnostic{}
		}
	}

	return result_message(result)
}*/
