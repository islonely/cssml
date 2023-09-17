module main

import os
import parser
import term

fn main() {
	cssml := os.read_file('./example.cssml') or {
		eprintln('Failed to read file.')
		exit(1)
	}
	mut p := parser.Parser.new(cssml)
	p.parse() or {
		eprintln(term.bright_red('error: ') + err.msg())
		exit(1)
	}
	// println(p.global_css)
	println(p.tree.html())
}
