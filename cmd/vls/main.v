module main

import vls

fn main() {
	mut ls := vls.Vls{
		send: fn (res string) {
			// print to stdout
			print(res)
		}
		// logging: os.getenv('VLS_LOG') == '1' || '-log' in os.args
	}
	ls.start_loop()
}
