import vls

fn test_initialize_with_capabilities() {
	payload := '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	mut ls := vls.Vls{}
	ls.execute(payload, fn (res string) {
		assert res == '{"jsonrpc":"2.0","id":1,"result":{"capabilities":{"textDocumentSync":1,"hoverProvider":false,"completionProvider":{"resolveProvider":false,"triggerCharacters":[]},"signatureHelpProvider":{"triggerCharacters":[],"retriggerCharacters":[]},"definitionProvider":false,"typeDefinitionProvider":false,"implementationProvider":false,"referencesProvider":false,"documentHightlightProvider":false,"documentSymbolProvider":true,"workspaceSymbolProvider":true,"codeActionProvider":false,"codeLensProvider":{"resolveProvider":false},"documentFormattingProvider":false,"documentOnTypeFormattingProvider":{"moreTriggerCharacter":[]},"renameProvider":false,"documentLinkProvider":false,"colorProvider":false,"declarationProvider":false,"executeCommandProvider":"","experimental":{}}}}'
	})
}

fn test_shutdown() {
	payload := '{"jsonrpc":"2.0","id":1,"method":"shutdown","params":{}}'
	mut ls := vls.Vls{}
	ls.execute(payload, fn (res string) {})
	assert ls.status() == .shutdown
}
