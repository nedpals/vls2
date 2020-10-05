module lsp

pub struct HoverSettings {
	dynamic_registration bool [json:dynamicRegistration]
	content_format []string [json:contentFormat]
}

// method: ‘textDocument/hover’
// response: Hover | none
// request: TextDocumentPositionParams
pub struct HoverParams {
pub:
	text_document TextDocumentIdentifier [json:textDocument]
	position Position
}

pub struct Hover {
pub:
	contents MarkedString
	range Range
}

// pub type MarkedString = string | MarkedStringS
pub struct MarkedString {
	language string
	value string
}

