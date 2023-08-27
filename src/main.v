module main

import os
import parser

fn main() {
	cssml := os.read_file('/workspaces/cssml/example.cssml') or {
		eprintln('Failed to read file.')
		exit(1)
	}
	mut p := parser.Parser.new(cssml.runes())
	p.parse()
}
