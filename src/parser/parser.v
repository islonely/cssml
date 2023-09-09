module parser

struct Parser {
mut:
	tokenizer Tokenizer
}

pub fn Parser.new(src string) Parser {
	return Parser{
		tokenizer: Tokenizer.new(src)
	}
}

pub fn (mut p Parser) parse() ! {
	mut tok := p.tokenizer.emit_token()!
	for tok !is EOFToken {
		println(tok)
		tok = p.tokenizer.emit_token()!
	}
	println(tok)
}
