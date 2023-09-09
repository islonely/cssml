module parser

import strings

const (
	newline        = '\n\f'.runes()
	whitespace     = '\n\r\f\t '.runes()
	hex            = '0123456789abcdefABCDEF'.runes()
	tag_name_chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'.runes()
	alpha          = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.runes()
	digits         = '0123456789'.runes()
	replacement    = rune(0xfffd)
)

enum TokenizerState {
	eof
	extern
	extern_after_query_selector
	extern_in_css_block
	in_comment
	in_css_rule_name
	in_css_rule_value
}

struct Tokenizer {
	src     []rune
	src_str string
mut:
	pos          int
	tok_len      int
	state        TokenizerState  = .extern
	return_state TokenizerState  = .extern
	buf          strings.Builder = strings.new_builder(100)
	attr         string
	inside_html  bool
	// current Token being modified
	token Token
}

[inline]
fn Tokenizer.new(src string) Tokenizer {
	return Tokenizer{
		src: src.runes()
		src_str: src
	}
}

[inline]
fn (t Tokenizer) current() rune {
	return t.src[t.pos]
}

[inline]
fn (t Tokenizer) next() ?rune {
	return if t.pos >= t.src.len {
		none
	} else {
		t.src[t.pos]
	}
}

fn (mut t Tokenizer) consume() ?rune {
	if t.pos >= t.src.len {
		return none
	}
	r := t.src[t.pos]
	t.pos++
	t.tok_len++
	return r
}

fn (mut t Tokenizer) emit_token() !Token {
	return match t.state {
		.eof { t.state__eof() }
		.extern { t.state__extern()! }
		.extern_after_query_selector { t.state__extern_after_query_selector()! }
		.extern_in_css_block { t.state__extern_in_css_block()! }
		.in_comment { t.state__in_comment() }
		.in_css_rule_name { t.state__in_css_rule_name()! }
		.in_css_rule_value { t.state__in_css_rule_value()! }
	}
}

// reset_buf returns the contents of the Tokenizer.buf field and sets
// it to a new string buidler.
fn (mut t Tokenizer) reset_buf() string {
	str := t.buf.str()
	t.buf = strings.new_builder(200)
	return str
}

// buf gets the contents of the Tokenizer.buf without freeing the memory.
[inline]
fn (mut t Tokenizer) buf() string {
	return t.buf.bytestr()
}

// state__eof returns an EOFToken (end-of-file) set to the current tokenizer position.
[inline]
fn (mut t Tokenizer) state__eof() Token {
	return EOFToken{
		pos: t.pos
		len: t.tok_len
	}
}

fn (mut t Tokenizer) state__extern() !Token {
	r := t.consume() or { return t.state__eof() }

	if r == `/` {
		if next := t.next() {
			if next == `/` {
				t.consume() or { panic('We just did t.next()?') }
				t.state = .in_comment
				t.return_state = .extern
				return t.state__in_comment()
			}
		}
	}

	if r in parser.newline {
		return t.state__extern()
	}

	if r in parser.tag_name_chars {
		t.buf.write_rune(r)
		return t.state__extern()
	}

	if r in parser.whitespace {
		if t.buf.bytestr() == 'html' {
			return TagToken{
				pos: t.pos - t.tok_len
				len: t.tok_len - 1 // -1 for whitespace
				name: 'html'
			}
		}

		t.state = .extern_after_query_selector
		defer {
			t.tok_len = 0
		}
		return CSSRuleOpen{
			pos: t.pos - t.tok_len
			len: t.tok_len - 1 // -1 for whitespace
			query_selector: t.reset_buf()
		}
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__extern_after_query_selector() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.whitespace {
		return t.state__extern_after_query_selector()!
	}

	if r == `{` {
		t.state = .extern_in_css_block
		return t.state__extern_in_css_block()!
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__extern_in_css_block() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.whitespace {
		return t.state__extern_in_css_block()!
	}

	if r in parser.tag_name_chars {
		t.return_state = .extern_in_css_block
		t.pos-- // reconsume as part of CSS rule name (--webkit-box-shadow)
		t.state = .in_css_rule_name
		return t.state__in_css_rule_name()!
	}

	if r == `}` {
		t.state = .extern
		defer {
			t.tok_len = 0
		}
		return CSSRuleClose{
			pos: t.pos - t.tok_len
			len: t.tok_len
		}
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__in_css_rule_name() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.newline {
		line, col := t.get_line_col()
		return error('Invalid EOL in CSSML (${t.state}) @${line}:${col}')
	}

	if r in parser.whitespace {
		line, col := t.get_line_col()
		return error('Invalid whitespace in CSSML (${t.state}) @${line}:${col}')
	}

	if r in parser.tag_name_chars {
		t.buf.write_rune(r)
		return t.state__in_css_rule_name()!
	}

	if r == `:` {
		t.token = CSSRule{
			pos: t.pos - t.tok_len
			name: t.reset_buf()
		}
		t.state = .in_css_rule_value
		return t.state__in_css_rule_value()!
	}

	line, col := t.get_line_col()
	println('here')
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__in_css_rule_value() !Token {
	r := t.consume() or { return t.state__eof() }

	if r == `;` {
		mut tok := t.token as CSSRule
		tok.len = t.tok_len
		t.tok_len = 0
		tok.value = t.reset_buf()
		t.state = t.return_state
		return tok
	}

	t.buf.write_rune(r)
	return t.state__in_css_rule_value()!
}

fn (mut t Tokenizer) state__in_comment() Token {
	r := t.consume() or {
		t.state = .eof
		defer {
			t.tok_len = 0
		}
		return CommentToken{
			pos: t.pos - t.tok_len
			len: t.tok_len
			text: t.reset_buf()
		}
	}

	if r in parser.newline {
		t.state = t.return_state
		defer {
			t.tok_len = 0
		}
		return CommentToken{
			pos: t.pos - t.tok_len
			len: t.tok_len - 1 // -1 for newline
			text: t.reset_buf()
		}
	}

	t.buf.write_rune(r)
	return t.state__in_comment()
}

// https://infra.spec.whatwg.org/#noncharacter
fn is_non_character(r rune) bool {
	for i := 0xFDD0; i <= 0xFDEF; i++ {
		if r == rune(i) {
			return true
		}
	}

	if r in [rune(0xFFFE), 0xFFFF, 0x1FFFE, 0x1FFFF, 0x2FFFE, 0x2FFFF, 0x3FFFE, 0x3FFFF, 0x4FFFE,
		0x4FFFF, 0x5FFFE, 0x5FFFF, 0x6FFFE, 0x6FFFF, 0x7FFFE, 0x7FFFF, 0x8FFFE, 0x8FFFF, 0x9FFFE,
		0x9FFFF, 0xAFFFE, 0xAFFFF, 0xBFFFE, 0xBFFFF, 0xCFFFE, 0xCFFFF, 0xDFFFE, 0xDFFFF, 0xEFFFE,
		0xEFFFF, 0xFFFFE, 0xFFFFF, 0x10FFFE, 0x10FFFF] {
		return true
	}

	return false
}

[direct_array_access]
fn (t Tokenizer) get_line_col() (int, int) {
	if t.pos < 0 || t.pos >= t.src_str.len {
		return -1, -1
	}

	lines_up_to_pos := t.src_str[..t.pos + 1].split_into_lines()
	line_no := lines_up_to_pos.len
	col_no := lines_up_to_pos[lines_up_to_pos.len - 1].len
	return line_no, col_no
}
