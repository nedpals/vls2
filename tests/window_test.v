import vls
import lsp

fn test_log_message() {
	ls := vls.Vls{
		send: fn (res string) {
			assert res == '{"jsonrpc":"2.0","method":"window/logMessage","params":{"type":3,"message":"Hello World!"}}'
		}
	}
	ls.log_message('Hello World!', .info)
}

fn test_show_message() {
	ls := vls.Vls{
		send: fn (res string) {
			assert res == '{"jsonrpc":"2.0","method":"window/showMessage","params":{"type":3,"message":"Hello World!"}}'
		}
	}
	ls.show_message('Hello World!', .info)
}
