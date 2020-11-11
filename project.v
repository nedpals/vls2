module main

import v.ast
import lsp
// import v.doc
// import v.token
// import v.fmt
// import os
// import v.table
// import v.checker

// TODO: ignore version in files for now.
struct Project {
	path string
mut:
	active_files []string
	cached_symbols []lsp.SymbolInformation
	cached_completion []lsp.CompletionItem
	nr_errors int
}

struct ProjectFileConfig {
	symbols []lsp.SymbolInformation
	completion []lsp.CompletionItem
}

fn new_project(project_dir string) Project {
	return Project{
		nr_errors: 0
		cached_symbols: []lsp.SymbolInformation{}
		cached_completion: []lsp.CompletionItem{}
	}
}

fn file_asts_arr(asts map[string]ast.File) []ast.File {
	mut file_asts := []ast.File{}
	for _, file_ast in asts {
		file_asts << file_ast
	}
	return file_asts
}

fn (mut prj Project) insert(filename string, insert ProjectFileConfig) {
	if insert.symbols.len > 0 {
		prj.cached_symbols = insert.symbols
	}

	if insert.completion.len > 0 {
		prj.cached_completion = insert.completion
	}
}

fn (mut prj Project) delete(filename string) {
	idx := prj.active_files.index(filename)
	if idx == -1 { return }
	prj.active_files.delete(idx)
}