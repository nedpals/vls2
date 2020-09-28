# vls
V Language Server that aims to be used with LSP v3.15-compatible clients.

## Current Status
vls is still a work-in-progress.

## Development
To start working with vls, you need to have git and the latest version of [V](https://github.com/vlang/v) installed. Then do the following:
```
git clone https://github.com/nedpals/vls.git && cd vls/

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
- [ ] `didClose`
### Diagnostics
- [x] `publishDiagnostics`
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
- [ ] `documentSymbol`
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
    
    
    
    

