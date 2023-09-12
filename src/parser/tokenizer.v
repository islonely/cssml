module parser

import datatypes { Stack }
import strings
import term

const (
	newline        = '\n\f'.runes()
	whitespace     = '\n\r\f\t '.runes()
	hex            = '0123456789abcdefABCDEF'.runes()
	query_sel_chars= 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'.runes()
	alpha          = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.runes()
	digits         = '0123456789'.runes()
	replacement    = rune(0xfffd)
)

enum TokenizerState {
	after_css_attr
	after_css_attr_value
	after_query_selector
	eof
	extern
	extern_after_query_selector
	extern_in_css_block
	in_comment
	in_css_block
	in_css_attr_name
	in_css_attr_value_double_quoted
	in_css_attr_value_single_quoted
	in_css_attr_value_unquoted
	in_css_class
	in_css_id
	in_css_pseudo_class
	in_css_pseudo_element
	in_css_rule_name
	in_css_rule_value
	in_query_selector
	start_css_attr
	start_css_attr_value
	start_css_class
	start_css_id
	start_css_pseudo_class
	start_css_pseudo_element
}

struct Tokenizer {
	src     []rune
	src_str string
mut:
	pos          int
	tok_len      int
	state        TokenizerState  = .extern
	return_state Stack[TokenizerState]
	buf          strings.Builder = strings.new_builder(100)
	attr         string
	inside_html  bool
	// current Token being modified
	token Token
}

// Tokenizer.new returns a new `Tokenizer` with the
// supplied source.
[inline]
fn Tokenizer.new(src string) Tokenizer {
	return Tokenizer{
		src: src.runes()
		src_str: src
	}
}

// current returns the character at the current position
// in the buffer.
[inline]
fn (t Tokenizer) current() rune {
	return t.src[t.pos]
}

// next returns the next character in the buffer or `none`.
[inline]
fn (t Tokenizer) next() ?rune {
	return if t.pos >= t.src.len {
		none
	} else {
		t.src[t.pos]
	}
}

// consume returns the current character in the buffer or `none`.
// It then moves the positition forward and increments the
// token length.
fn (mut t Tokenizer) consume() ?rune {
	if t.pos >= t.src.len {
		return none
	}
	r := t.src[t.pos]
	t.pos++
	t.tok_len++
	return r
}

// emit_token returns a `Token` based on the current
// `Tokenizer` state or an error.
fn (mut t Tokenizer) emit_token() !Token {
	return match t.state {
		.after_css_attr { t.state__after_css_attr()! }
		.after_css_attr_value { t.state__after_css_attr_value()! }
		.after_query_selector { t.state__after_query_selector()! }
		.eof { t.state__eof() }
		.extern { t.state__extern()! }
		.extern_after_query_selector { t.state__extern_after_query_selector()! }
		.extern_in_css_block { t.state__extern_in_css_block()! }
		.in_comment { t.state__in_comment()! }
		.in_css_block { t.state__in_css_block()! }
		.in_css_attr_name { t.state__in_css_attr_name()! }
		.in_css_attr_value_double_quoted { t.state__in_css_attr_value_double_quoted()! }
		.in_css_attr_value_single_quoted { t.state__in_css_attr_value_single_quoted()! }
		.in_css_attr_value_unquoted { t.state__in_css_attr_value_unquoted()! }
		.in_css_class { t.state__in_css_class()! }
		.in_css_id { t.state__in_css_id()! }
		.in_css_pseudo_class { t.state__in_css_pseudo_class()! }
		.in_css_pseudo_element { t.state__in_css_pseudo_element()! }
		.in_css_rule_name { t.state__in_css_rule_name()! }
		.in_css_rule_value { t.state__in_css_rule_value()! }
		.in_query_selector { t.state__in_query_selector()! }
		.start_css_attr { t.state__start_css_attr()! }
		.start_css_attr_value { t.state__start_css_attr_value()! }
		.start_css_class { t.state__start_css_class()! }
		.start_css_id { t.state__start_css_id()! }
		.start_css_pseudo_class { t.state__start_css_pseudo_class()! }
		.start_css_pseudo_element { t.state__start_css_pseudo_element()! }
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

// index_any_after returns the index and character of any of the supplied
// characters after the current position in the source or `none`.
fn (t Tokenizer) index_any_after(chars string) ?(int, rune) {
	for i, character in t.src[t.pos..] {
		if character in chars.runes() {
			return i, character
		}
	}
	return none
}

// state__eof returns an EOFToken (end-of-file) set to the current tokenizer position.
[inline]
fn (mut t Tokenizer) state__eof() Token {
	return EOFToken{
		pos: t.pos
		len: t.tok_len
	}
}

fn (mut t Tokenizer) state__after_query_selector() !Token {
	r := t.consume() or { return t.state__eof() }

	if r == `{` {
		t.state = .in_css_block
		return t.state__in_css_block()!
	}

	if r in parser.whitespace {
		return t.state__after_query_selector()
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS block ({}) must come after CSS query selector (html, body, etc.).')
}

fn (mut t Tokenizer) state__extern() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.whitespace && t.buf.len > 0 {
		defer {
			t.tok_len = 0
		}
		t.token = CSSRuleOpen{
			pos: t.pos - t.tok_len
			len: t.tok_len - 1 // -1 for whitespace
			name: t.reset_buf()
		}

		if (t.token as CSSRuleOpen).name == 'html' {
			t.state = .after_query_selector
		} else {
			t.state = .extern_after_query_selector
		}
		return t.token
	}

	if r == `/` {
		if next := t.next() {
			if next == `/` {
				t.consume() or { panic('We just did t.next()?') }
				t.state = .in_comment
				t.return_state.push(TokenizerState.extern)
				return t.state__in_comment()
			}
		}
	}

	if r in parser.whitespace {
		return t.state__extern()
	}

	if r in parser.query_sel_chars {
		t.buf.write_rune(r)
		return t.state__extern()
	}

	if r == `#` {
		t.token = CSSRuleOpen{
			pos: t.pos - t.tok_len
			name: t.reset_buf()
		}
		t.state = .start_css_id
		t.return_state.push(TokenizerState.extern_after_query_selector)
		return t.state__start_css_id()!
	}

	if r == `.` {
		t.token = CSSRuleOpen{
			pos: t.pos - t.tok_len
			name: t.reset_buf()
		}
		t.state = .start_css_class
		t.return_state.push(TokenizerState.extern_after_query_selector)
		return t.state__start_css_class()!
	}

	if r == `:` {
		t.token = CSSRuleOpen{
			pos: t.pos - t.tok_len
			name: t.reset_buf()
		}
		t.return_state.push(TokenizerState.extern_after_query_selector)
		if next := t.consume() {
			if next == `:` {
				t.state = .start_css_pseudo_element
				return t.state__start_css_pseudo_element()!
			}

			t.buf.write_rune(next)
			t.state = .start_css_pseudo_class
			return t.state__start_css_pseudo_class()!
		}

		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	if r == `[` {
		t.token = CSSRuleOpen{
			pos: t.pos - t.tok_len
			name: t.reset_buf()
		}
		t.return_state.push(TokenizerState.extern_after_query_selector)
		t.state = .start_css_attr
		return t.state__start_css_attr()!
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__start_css_attr() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.query_sel_chars {
		t.buf.write_rune(r)
		t.state = .in_css_attr_name
		return t.state__in_css_attr_name()!
	}

	if r == `]` {
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS attribute ([attr_name="attr_value"]) cannot be empty.')
	}

	if r == `=` {
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS attribute ([attr_name="attr_value"]) missing name.')
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__in_css_attr_name() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.query_sel_chars {
		t.buf.write_rune(r)
		return t.state__in_css_attr_name()!
	}

	if r == `]` {
		mut tok := t.token as CSSRuleOpen
		t.attr = t.reset_buf()
		tok.attributes[t.attr] = none
		t.token = tok
		t.state = .after_css_attr
		return t.state__after_css_attr()!
	}

	if r == `=` {
		mut tok := t.token as CSSRuleOpen
		t.attr = t.reset_buf()
		tok.attributes[t.attr] = none
		t.token = tok
		t.state = .start_css_attr_value
		return t.state__start_css_attr_value()!
	}

	if r in parser.whitespace {
		line, col := t.get_line_col()
		return error('Unexpected whitespace in CSSML (${t.state}) @${line}:${col}')
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS attribute ([attr_name="attr_value"]) missing value.')
}

fn (mut t Tokenizer) state__start_css_attr_value() !Token {
	r := t.consume() or { return t.state__eof() }

	if r == `"` {
		t.state = .in_css_attr_value_double_quoted
		return t.state__in_css_attr_value_double_quoted()!
	}

	if r == `'` {
		t.state = .in_css_attr_value_single_quoted
		return t.state__in_css_attr_value_single_quoted()!
	}

	if r == `]` {
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS attribute ([attr_name="attr_value"]) missing value.')
	}

	if r in parser.whitespace {
		line, col := t.get_line_col()
		return error('Unexpected whitespace in CSSML (${t.state}) @${line}:${col}')
	}

	t.buf.write_rune(r)
	t.state = .in_css_attr_value_unquoted
	return t.state__in_css_attr_value_unquoted()!
}

fn (mut t Tokenizer) state__in_css_attr_value_double_quoted() !Token {
	r := t.consume() or { return t.state__eof() }

	if r == `"` {
		mut tok := t.token as CSSRuleOpen
		tok.attributes[t.attr] = t.reset_buf()
		t.token = tok
		t.state = .after_css_attr_value
		return t.state__after_css_attr_value()!
	}

	if r == `\\` {
		if next := t.consume() {
			t.buf.write_rune(r)
			t.buf.write_rune(next)
			return t.state__in_css_attr_value_double_quoted()!
		}

		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	t.buf.write_rune(r)
	return t.state__in_css_attr_value_double_quoted()!
}

fn (mut t Tokenizer) state__in_css_attr_value_single_quoted() !Token {
	r := t.consume() or { return t.state__eof() }

	if r == `'` {
		mut tok := t.token as CSSRuleOpen
		tok.attributes[t.attr] = t.reset_buf()
		t.token = tok
		t.state = .after_css_attr_value
		return t.state__after_css_attr_value()!
	}

	if r == `\\` {
		if next := t.consume() {
			t.buf.write_rune(r)
			t.buf.write_rune(next)
			return t.state__in_css_attr_value_single_quoted()!
		}

		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	t.buf.write_rune(r)
	return t.state__in_css_attr_value_single_quoted()!
}

fn (mut t Tokenizer) state__in_css_attr_value_unquoted() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.whitespace {
		line, col := t.get_line_col()
		return error('Unexpected whitespace in CSSML (${t.state}) @${line}:${col}')
	}

	if r == `]` {
		mut tok := t.token as CSSRuleOpen
		tok.attributes[t.attr] = t.reset_buf()
		t.token = tok
		t.state = .after_css_attr
		return t.state__after_css_attr()!
	}

	if r == `\\` {
		if next := t.consume() {
			if next == `]` {
				line, col := t.get_line_col()
				return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nUnquoted CSS attribute ([attr_name="attr_value"]) cannot contain a backslash (\\) followed by a closing bracket (]).')
			}

			t.buf.write_rune(r)
			t.buf.write_rune(next)
			return t.state__in_css_attr_value_unquoted()!
		}

		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	t.buf.write_rune(r)
	return t.state__in_css_attr_value_unquoted()!
}

fn (mut t Tokenizer) state__after_css_attr_value() !Token {
	r := t.consume() or { return t.state__eof() }

	if r == `]` {
		t.state = .after_css_attr
		return t.state__after_css_attr()!
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__after_css_attr() !Token {
	r := t.consume() or { return t.state__eof() }

	if r == `#` {
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS id (#id_name) must come before CSS attribute ([attr_name="attr_value"]).')
	}

	if r == `.` {
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS class (.class_name) must come before CSS attribute ([attr_name="attr_value"]).')
	}

	if r == `:` {
		if next := t.consume() {
			if next == `:` {
				t.state = .start_css_pseudo_element
				return t.state__start_css_pseudo_element()!
			}

			t.buf.write_rune(next)
			t.state = .start_css_pseudo_class
			return t.state__start_css_pseudo_class()!
		}

		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	if r == `[` {
		t.state = .start_css_attr
		return t.state__start_css_attr()!
	}

	if r in parser.whitespace {
		t.state = t.return_state.pop()!
		mut tok := t.token as CSSRuleOpen
		tok.len = t.tok_len - 1 // -1 for whitespace
		t.tok_len = 0
		return tok
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__start_css_pseudo_class() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.query_sel_chars {
		t.buf.write_rune(r)
		t.state = .in_css_pseudo_class
		return t.state__in_css_pseudo_class()!
	}

	if r in parser.whitespace {
		line, col := t.get_line_col()
		return error('Unexpected whitespace in CSSML (${t.state}) @${line}:${col}')
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__in_css_pseudo_class() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.query_sel_chars {
		t.buf.write_rune(r)
		return t.state__in_css_pseudo_class()!
	}

	if r == `(` {
		t.buf.write_rune(r)
		mut next := t.consume() or {
			line, col := t.get_line_col()
			return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
		}
		for {
			if next in parser.query_sel_chars {
				t.buf.write_rune(next)
				next = t.consume() or {
					line, col := t.get_line_col()
					return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
				}
				continue
			}

			if next == `)` {
				t.buf.write_rune(next)
				mut tok := t.token as CSSRuleOpen
				tok.pseudo.classes << t.reset_buf()
				tok.len = t.tok_len - 1 // -1 for whitespace
				t.tok_len = 0
				t.state = t.return_state.pop()!
				return tok
			}
		}
	}

	if r == `:` {
		mut tok := t.token as CSSRuleOpen
		tok.pseudo.classes << t.reset_buf()
		t.token = tok
		
		if next := t.consume() {
			if next == `:` {
				t.state = .start_css_pseudo_element
				return t.state__start_css_pseudo_element()!
			}

			t.buf.write_rune(next)
			t.state = .start_css_pseudo_class
			return t.state__start_css_pseudo_class()!
		}

		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	if r == `#` {
		mut tok := t.token as CSSRuleOpen
		tok.pseudo.classes << t.reset_buf()
		t.token = tok
		
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS pseudo class (:class_name) must come after CSS id (#id_name).')
	}

	if r == `.` {
		mut tok := t.token as CSSRuleOpen
		tok.pseudo.classes << t.reset_buf()
		t.token = tok
		
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS pseudo class (:class_name) must come after CSS class (.class_name).')
	}

	if r == `[` {
		mut tok := t.token as CSSRuleOpen
		tok.pseudo.classes << t.reset_buf()
		t.token = tok
		
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS pseudo class (:class_name) must come after CSS attribute ([attr_name="attr_value"]).')
	}

	if r in parser.whitespace {
		mut tok := t.token as CSSRuleOpen
		tok.pseudo.classes << t.reset_buf()
		tok.len = t.tok_len - 1 // -1 for whitespace
		t.tok_len = 0
		t.state = t.return_state.pop()!
		return tok
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__start_css_pseudo_element() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.query_sel_chars {
		t.buf.write_rune(r)
		t.state = .in_css_pseudo_element
		return t.state__in_css_pseudo_element()!
	}

	if r in parser.whitespace {
		line, col := t.get_line_col()
		return error('Unexpected whitespace in CSSML (${t.state}) @${line}:${col}')
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__in_css_pseudo_element() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.query_sel_chars {
		t.buf.write_rune(r)
		return t.state__in_css_pseudo_class()!
	}

	if r == `:` {
		mut tok := t.token as CSSRuleOpen
		tok.pseudo.elements << t.reset_buf()
		t.token = tok

		if next := t.consume() {
			if next == `:` {
				line, col := t.get_line_col()
				return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nOnly one pseudo element (::pseduo_element) can be used per CSS block.')
			}

			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS pseudo element (::pseduo_element) must come after CSS pseudo class (:class_name).')
		}
		
		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	if r == `#` {
		mut tok := t.token as CSSRuleOpen
		tok.pseudo.elements << t.reset_buf()
		t.token = tok
		
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS pseudo element (::pseduo_element) must come after CSS id (#id_name).')
	}

	if r == `.` {
		mut tok := t.token as CSSRuleOpen
		tok.pseudo.elements << t.reset_buf()
		t.token = tok
		
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS pseudo element (::pseduo_element) must come after CSS class (.class_name).')
	}

	if r == `[` {
		mut tok := t.token as CSSRuleOpen
		tok.pseudo.elements << t.reset_buf()
		t.token = tok
		
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS pseudo element (::pseduo_element) must come after CSS attribute ([attr_name="attr_value"]).')
	}

	if r in parser.whitespace {
		mut tok := t.token as CSSRuleOpen
		tok.pseudo.elements << t.reset_buf()
		tok.len = t.tok_len - 1 // -1 for whitespace
		t.tok_len = 0
		t.state = t.return_state.pop()!
		return tok
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__start_css_class() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.query_sel_chars {
		t.buf.write_rune(r)
		t.state = .in_css_class
		return t.state__in_css_class()!
	}

	if r == `-` {
		if next := t.consume() {
			if next != `-` && next !in parser.digits {
				t.buf.write_rune(r)
				t.buf.write_rune(next)
				t.state = .in_css_class
				return t.state__in_css_class()!
			}

			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS class (.class_name) cannot start with a hyphen (-) followed by another hyphen or digit (0-9).')
		}

		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	if r >= `0` && r <= `9` {
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS class (.class_name) cannot start with a digit (0-9).')
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__in_css_class() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.query_sel_chars {
		t.buf.write_rune(r)
		t.state = .in_css_class
		return t.state__in_css_class()!
	}

	if r in parser.whitespace {
		mut tok := t.token as CSSRuleOpen
		tok.classes << t.reset_buf()
		tok.len = t.tok_len - 1 // -1 for whitespace
		t.tok_len = 0
		t.state = t.return_state.pop()!
		return tok
	}

	if r == `#` {
		mut tok := t.token as CSSRuleOpen
		tok.classes << t.reset_buf()
		t.token = tok
		
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS id (#id_name) must come before CSS class (.class_name).')
	}

	if r == `.` {
		mut tok := t.token as CSSRuleOpen
		tok.classes << t.reset_buf()
		t.token = tok
		t.state = .start_css_class
		return t.state__start_css_class()!
	}

	if r == `:` {
		mut tok := t.token as CSSRuleOpen
		tok.classes << t.reset_buf()
		t.token = tok
		
		if next := t.consume() {
			if next == `:` {
				t.state = .start_css_pseudo_element
				return t.state__start_css_pseudo_element()!
			}

			t.buf.write_rune(next)
			t.state = .start_css_pseudo_class
			return t.state__start_css_pseudo_class()!
		}

		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	if r == `[` {
		mut tok := t.token as CSSRuleOpen
		tok.classes << t.reset_buf()
		t.token = tok
		t.state = .start_css_attr
		return t.state__start_css_attr()!
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__start_css_id() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.query_sel_chars {
		t.buf.write_rune(r)
		t.state = .in_css_id
		return t.state__in_css_id()!
	}

	if r == `-` {
		if next := t.consume() {
			if next != `-` && next !in parser.digits {
				t.buf.write_rune(r)
				t.buf.write_rune(next)
				t.state = .in_css_id
				return t.state__in_css_id()!
			}

			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS id (#id_name) cannot start with a hyphen (-) followed by another hyphen or digit (0-9).')
		}

		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	if r >= `0` && r <= `9` {
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS id (#id_name) cannot start with a digit (0-9).')
	}

	line, col := t.get_line_col()
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__in_css_id() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.query_sel_chars {
		t.buf.write_rune(r)
		t.state = .in_css_id
		return t.state__in_css_id()!
	}

	if r in parser.whitespace {
		mut tok := t.token as CSSRuleOpen
		tok.id = t.reset_buf()
		tok.len = t.tok_len - 1 // -1 for whitespace
		t.tok_len = 0
		t.state = t.return_state.pop()!
		return tok
	}

	if r == `#` {
		mut tok := t.token as CSSRuleOpen
		tok.id = t.reset_buf()
		t.token = tok
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS id (#id_name) must be unique.')
	}

	if r == `.` {
		mut tok := t.token as CSSRuleOpen
		tok.id = t.reset_buf()
		t.token = tok
		t.state = .start_css_class
		return t.state__start_css_class()!
	}

	if r == `:` {
		mut tok := t.token as CSSRuleOpen
		tok.id = t.reset_buf()
		t.token = tok
		
		if next := t.consume() {
			if next == `:` {
				t.state = .start_css_pseudo_element
				return t.state__start_css_pseudo_element()!
			}

			t.buf.write_rune(next)
			t.state = .start_css_pseudo_class
			return t.state__start_css_pseudo_class()!
		}

		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	if r == `[` {
		mut tok := t.token as CSSRuleOpen
		tok.id = t.reset_buf()
		t.token = tok
		t.state = .start_css_attr
		return t.state__start_css_attr()!
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

	if r in parser.query_sel_chars {
		t.return_state.push(TokenizerState.extern_in_css_block)
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

fn (mut t Tokenizer) state__in_query_selector() !Token {
	r := t.consume() or { return t.state__eof() }

	if r in parser.whitespace {
		if t.buf.len > 0 {
			mut tok := t.token as CSSRuleOpen
			tok.name = t.reset_buf()
			t.token = tok
			t.state = .after_query_selector
			return t.token
		}

		return t.state__in_query_selector()!
	}

	if r == `#` {
		mut tok := t.token as CSSRuleOpen
		if tok.classes.len > 0 {
			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS id (#id_name) must come before CSS class (.class_name).')
		}

		if tok.id.len > 0 {
			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nOnly one CSS id (#id_name) can be used per CSS block.')
		}

		if tok.pseudo.classes.len > 0 {
			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS id (#id_name) must come before CSS pseudo class (:class_name).')
		}

		if tok.pseudo.elements.len > 0 {
			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS id (#id_name) must come before CSS pseudo element (::pseduo_element).')
		}

		if tok.attributes.len > 0 {
			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS id (#id_name) must come before CSS attribute ([attr_name="attr_value"]).')
		}

		tok.name = t.reset_buf()
		t.token = tok
		t.state = .start_css_id
		return t.state__start_css_id()!
	}

	if r == `.` {
		mut tok := t.token as CSSRuleOpen
		if tok.pseudo.classes.len > 0 {
			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS class (.class_name) must come before CSS pseudo class (:class_name).')
		}

		if tok.pseudo.elements.len > 0 {
			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS class (.class_name) must come before CSS pseudo element (::pseduo_element).')
		}

		if tok.attributes.len > 0 {
			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS class (.class_name) must come before CSS attribute ([attr_name="attr_value"]).')
		}

		tok.name = t.reset_buf()
		t.token = tok
		t.state = .start_css_class
		return t.state__start_css_class()!
	}

	if r == `[` {
		mut tok := t.token as CSSRuleOpen
		if tok.pseudo.classes.len > 0 {
			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS attribute ([attr_name="attr_value"]) must come before CSS pseudo class (:class_name).')
		}

		if tok.pseudo.elements.len > 0 {
			line, col := t.get_line_col()
			return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}\nCSS attribute ([attr_name="attr_value"]) must come before CSS pseudo element (::pseduo_element).')
		}

		tok.name = t.reset_buf()
		t.token = tok
		t.state = .start_css_attr
		return t.state__start_css_attr()!
	}

	if r == `:` {
		if next := t.consume() {
			mut tok := t.token as CSSRuleOpen
			tok.name = t.reset_buf()
			if next == `:` {
				t.token = tok
				t.state = .start_css_pseudo_element
				return t.state__start_css_pseudo_element()!
			}

			t.buf.write_rune(next)
			t.token = tok
			t.state = .start_css_pseudo_class
			return t.state__start_css_pseudo_class()!
		}

		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	t.buf.write_rune(r)
	return t.state__in_query_selector()!
}

fn (mut t Tokenizer) state__in_css_block() !Token {
	r := t.consume() or { return t.state__eof() }

	if r == `/` {
		if next := t.consume() {
			if next == `/` {
				t.state = .in_comment
				t.return_state.push(TokenizerState.in_css_block)
				return t.state__in_comment()!
			}
		}
		
		line, col := t.get_line_col()
		return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
	}

	if r == `>` {
		t.token = CSSRuleOpen{
			pos: t.pos - t.tok_len
			direct_child: true
		}
		t.state = .in_query_selector
		t.return_state.push(TokenizerState.in_css_block)
		return t.state__in_query_selector()!
	}

	if r in parser.whitespace {
		return t.state__in_css_block()!
	}

	// CSS rule (background-color: red;) starts with the same characters as a query selector (div#id.class[attr="value"])
	// so we need to check if this is a CSS rule or a query selector.
	if r in parser.query_sel_chars {
		t.buf.write_rune(r)
		if _, find_out_if_this_is_css_rule_or_query_selector := t.index_any_after(':{') {
			// CSS query selector (div#id.class[attr="value"]) may contain a colon (:) for pseudo classes and elements.
			// So we need to check if this is the beginning of a pseudo class or element or the end of a CSS rule name.
			if find_out_if_this_is_css_rule_or_query_selector == `:` {
				if _, find_out_if_this_is_end_of_css_rule_name_or_start_of_psuedo_class := t.index_any_after(';{') {
					if find_out_if_this_is_end_of_css_rule_name_or_start_of_psuedo_class == `;` {
						t.return_state.push(TokenizerState.in_css_block)
						t.state = .in_css_rule_name
						return t.state__in_css_rule_name()!
					}

					//if find_out_if_this_is_end_of_css_rule_name_or_start_of_psuedo_class == `{` {
					t.token = CSSRuleOpen{
						pos: t.pos - t.tok_len
					}
					t.state = .in_query_selector
					t.return_state.push(TokenizerState.in_css_block)
					return t.state__in_query_selector()!
					//}
				}

				line, col := t.get_line_col()
				return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
			}

			//if find_out_if_this_is_css_rule_or_query_selector == `{` {
			t.token = CSSRuleOpen{
				pos: t.pos - t.tok_len
			}
			t.state = .in_query_selector
			return t.state__in_query_selector()!
			//}
		}

		line, col := t.get_line_col()
		return error('Unexpected end of file in CSSML (${t.state}) @${line}:${col}')
	}

	if r == `}` {
		t.state = .eof
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

	if r in parser.query_sel_chars {
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
	return error('Invalid character in CSSML (${t.state}): "${r}" @${line}:${col}')
}

fn (mut t Tokenizer) state__in_css_rule_value() !Token {
	r := t.consume() or { return t.state__eof() }

	if r == `;` {
		mut tok := t.token as CSSRule
		tok.len = t.tok_len
		t.tok_len = 0
		tok.value = t.reset_buf()
		t.state = t.return_state.pop()!
		return tok
	}

	t.buf.write_rune(r)
	return t.state__in_css_rule_value()!
}

fn (mut t Tokenizer) state__in_comment() !Token {
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
		t.state = t.return_state.pop()!
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
