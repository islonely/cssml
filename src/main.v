module main

import cli
import os
import parser
import term

const (
	no_args = 'Usage: cssml [options] <file>

Options:
	-h, --help     output usage information
	-v, --version  output the version number'
)

fn main() {
	// cssml := os.read_file('./example.cssml') or {
	// 	eprintln('Failed to read file.')
	// 	exit(1)
	// }
	// mut p := parser.Parser.new(cssml)
	// p.parse() or {
	// 	eprintln(term.bright_red('error: ') + err.msg())
	// 	exit(1)
	// }
	// // println(p.global_css)
	// println(p.tree.html())
	mut app := cli.Command{
		name: 'cssml',
		description: 'A CSSML compiler - CSS and HTML in one file.',
		execute: fn (cmd cli.Command) ! {
			watch := cmd.flags.get_bool('-watch') or { false }
			if !watch {
				for arg in cmd.args {
					abs_path := os.abs_path(arg)
					if os.is_dir(abs_path) {
						compile_directory(abs_path)
					} else {
						compile_file(abs_path)
					}
				}
			}
		},
		flags: [
			cli.Flag{
				flag: .bool
				name: '-watch',
				abbrev: 'w',
				description: 'Watch for changes and recompile.',
			}
		]
	}
	app.setup()
	app.parse(os.args)
}

fn compile_directory(abs_path string) {

}

fn compile_file(abs_path string) {
	abs_directory := os.dir(abs_path)
	file_name := os.file_name(abs_path).split('.')[0]
	file_ext := '.cssml'

	if abs_path.contains('.') {
		ext := abs_path.split('.').last()
		if ext != 'cssml' {
			eprintln('Unexpected file extension: ${ext}')
			exit(1)
		}
	} else {
		eprintln('warning: no file extension found; assuming .cssml')
	}

	src_file_contents := os.read_file(abs_path) or {
		eprintln('Failed to read file: ${err.msg()}')
		exit(1)
	}
	mut cssml_parser := parser.Parser.new(src_file_contents)
	cssml_parser.parse() or {
		eprintln(term.bright_red('error: ') + err.msg())
		exit(1)
	}

	dest_file_contents := cssml_parser.tree.html()
	dest_file_path := abs_directory + os.path_separator + file_name + '.html'
	os.write_file(dest_file_path, dest_file_contents) or {
		eprintln('Failed to write file: ${err.msg()}')
		exit(1)
	}
}