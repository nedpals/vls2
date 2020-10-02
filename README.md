# vls2
VLS (V Language Server) is a LSP v3.15-compatible language server for V.

## Current Status
vls is a work-in-progress. It requires a modified version of [vscode-vlang#166](https://github.com/vlang/vscode-vlang/pull/166) to run and interact with the server.

Windows support is also unstable for now. Please file an issue if you experience problems with it.

## Development
To start working with vls, you need to have git and the latest version of [V](https://github.com/vlang/v) installed. Then do the following:
```
git clone https://github.com/nedpals/vls2.git vls && cd vls/

# Build the project
v -o vls .

# Run the server
./vls
```

## Roadmap
- [ ] Queue support (support for cancelling requests)

### General
- [x] `initialize`
- [x] `initialized`
- [x] `shutdown`
- [x] `exit`
- [ ] `$/cancelRequest` (VLS does not support request cancellation yet.)
### Window
- [x] `showMessage`
- [x] `showMessageRequest`
- [x] `logMessage`
- [ ] `progress/create`
### Telemetry
- [ ] `event`
### Client
- [ ] `registerCapability`
- [ ] `unregisterCapability`
### Workspace
- [ ] `workspaceFolders`
- [ ] `didChangeWorkspaceFolder`
- [ ] `didChangeConfiguration`
- [ ] `configuration`
- [ ] `didChangeWatchedFiles` (use `didOpen`/`didSave` instead)
- [x] `symbol` (initial support)
- [ ] `executeCommand`
- [ ] `applyEdit`
### Text Synchronization
- [x] `didOpen`
- [ ] `didChange`
- [ ] `willSave`
- [ ] `willSaveWaitUntil`
- [x] `didSave`
- [x] `didClose`
### Diagnostics
- [x] `publishDiagnostics` (initial support)
### Language Features
- [ ] `completion`
- [ ] `completion resolve`
- [ ] `hover`
- [ ] `signatureHelp`
- [ ] `declaration`
- [ ] `definition`
- [ ] `typeDefinition`
- [ ] `implementation`
- [ ] `references`
- [ ] `documentHighlight`
- [x] `documentSymbol` (initial support)
- [ ] `codeAction`
- [ ] `codeLens`
- [ ] `codeLens resolve`
- [ ] `documentLink`
- [ ] `documentLink resolve`
- [ ] `documentColor`
- [ ] `colorPresentation`
- [ ] `formatting`
- [ ] `rangeFormatting`
- [ ] `onTypeFormatting`
- [ ] `rename`
- [ ] `prepareRename`
- [ ] `foldingRange`
    
    
    
    

