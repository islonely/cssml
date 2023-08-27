module parser

import strings

const (
	alphahyphen = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-'.runes()
	alpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.runes()
	whitespace = [rune(0x0009), 0x000a, 0x000c, 0x000d, 0x0020]
)

enum TokenizerState {
	before_tag_name
	tag_name
	after_tag
	tag_id
	tag_class
	attribute_name
	attribute_value
	style_attribute
	before_css_rule_name
	css_rule_name
	css_rule_value
	inner_text
	in_comment
	eof
}

struct Tokenizer {
	src []rune
mut:
	pos int = -1
	// it's more convenient to generate multiple tokens than one at a time
	// for some CSSML. But we still want to emit only one token at a time.
	// So we add them to a buffer and the token emitter will pull from the
	// front of the buffer. It shouldn't emit more than 10 at a time.
	buffer []Token = []Token{cap: 10}
	state TokenizerState = .before_tag_name
	str strings.Builder = strings.new_builder(100)
	attr string
	// current Token being modified
	token Token
}

[inline]
fn Tokenizer.new(src []rune) Tokenizer {
	return Tokenizer{src: src}
}

[inline]
fn (t Tokenizer) current() rune {
	return t.src[t.pos]
}

[inline]
fn (t Tokenizer) next() ?rune {
	return if t.pos + 1 >= t.src.len {
		none
	} else {
		t.src[t.pos + 1]
	}
}

[inline]
fn (mut t Tokenizer) consume() ?rune {
	next := t.next()?
	t.pos++
	return next
}

fn (mut t Tokenizer) emit_token() Token {
	if _unlikely_(t.state == .eof) {
		return Token(EOFToken(t.pos))
	}
	if t.buffer.len == 0 {
		t.buffer << match t.state {
			.before_tag_name { t.before_tag_name() }
			.tag_name { t.tag_name() }
			.tag_id { t.tag_id() }
			.tag_class { t.tag_class() }
			.attribute_name { t.attribute_name() }
			.attribute_value { t.attribute_value() }
			.after_tag { t.after_tag() }
			.before_css_rule_name { t.before_css_rule_name() }
			.css_rule_name { t.css_rule_name() }
			.css_rule_value { t.css_rule_value() }
			.inner_text { t.inner_text() }
			// .in_comment {}
			.eof { t.eof() }
			else { [Token(EOFToken(t.pos))] }
		}
	}

	tok := t.buffer.first()
	t.buffer.delete(0)
	return tok
}

fn (mut t Tokenizer) before_tag_name() []Token {
	r := t.consume() or {
		return t.eof()
	}

	if r in parser.alphahyphen {
		t.str = strings.new_builder(100)
		t.str.write_rune(r)
		t.state = .tag_name
		t.token = TagToken{pos: t.pos}
		return t.tag_name()
	}

	// ignore whitespace. all other characters are invalid.
	if r !in parser.whitespace {
		println('Invalid character "${r}".')
	}
	return t.before_tag_name()
}

fn (mut t Tokenizer) tag_name() []Token {
	r := t.consume() or {
		return t.eof()
	}

	if r in parser.alphahyphen {
		t.str.write_rune(r)
		return t.tag_name()
	}

	if r == `#` {
		mut tag := t.token as TagToken
		tag.pos = t.pos
		tag.name = t.str.str()
		t.str = strings.new_builder(100)
		t.token = tag
		t.state = .tag_id
		if tag.class.len > 0 {
			println('Tag id should come before the class(es).')
		}
		if tag.attributes.len > 0 {
			println('Tag id should come before other attributes.')
		}
		return t.tag_id()
	}

	if r == `.` {
		mut tag := t.token as TagToken
		tag.name = t.str.str()
		tag.pos = t.pos
		t.str = strings.new_builder(100)
		t.token = tag
		t.state = .tag_class
		if tag.id.len == 0 {
			println('Tag class(es) should come after the id.')
		}
		if tag.attributes.len > 0 {
			println('Tag class(es) should come before other attributes.')
		}
		return t.tag_class()
	}

	if r == `$` {
		mut tag := t.token as TagToken
		tag.name = t.str.str()
		tag.pos = t.pos
		t.str = strings.new_builder(100)
		t.token = tag
		t.state = .attribute_name
		return t.attribute_name()
	}

	if r !in parser.whitespace {
		t.pos--
	}

	mut tag := t.token as TagToken
	tag.name = t.str.str()
	t.state = .after_tag
	t.str = strings.new_builder(100)
	return [Token(tag)]
}

fn (mut t Tokenizer) after_tag() []Token {
	r := t.consume() or {
		return t.eof()
	}

	if r == `{` {
		t.state = .before_css_rule_name
		t.str = strings.new_builder(100)
		return t.before_css_rule_name()
	}

	if r !in parser.whitespace {
		println('Invalid character after tag name: ${r}')
	}

	return t.after_tag()
}

fn (mut t Tokenizer) tag_id() []Token {
	r := t.consume() or {
		return t.eof()
	}

	if r in parser.alphahyphen {
		t.str.write_rune(r)
		return t.tag_id()
	}

	if r == `.` {
		mut tag := t.token as TagToken
		tag.id = t.str.str()
		t.str = strings.new_builder(100)
		t.token = tag
		t.state = .tag_class
		return t.tag_class()
	}

	if r == `$` {
		mut tag := t.token as TagToken
		tag.id = t.str.str()
		t.str = strings.new_builder(100)
		t.token = tag
		t.state = .attribute_name
		return t.attribute_name()
	}

	if r !in parser.whitespace {
		println('Invalid character in tag id: ${r}')
	}
	t.state = .after_tag
	t.str = strings.new_builder(100)
	return [t.token]
}

fn (mut t Tokenizer) tag_class() []Token {
	r := t.consume() or {
		return t.eof()
	}

	if r in parser.alphahyphen {
		t.str.write_rune(r)
		return t.tag_class()
	}

	if r == `.` {
		mut tag := t.token as TagToken
		tag.class << t.str.str()
		t.str = strings.new_builder(100)
		t.token = tag
		return t.tag_class()
	}

	if r == `#` {
		mut tag := t.token as TagToken
		tag.class << t.str.str()
		t.str = strings.new_builder(100)
		t.token = tag
		t.state = .tag_id
		return t.tag_id()
	}

	if r == `$` {
		mut tag := t.token as TagToken
		tag.class << t.str.str()
		t.str = strings.new_builder(100)
		t.token = tag
		t.state = .attribute_name
		return t.attribute_name()
	}

	if r !in parser.whitespace {
		println('Invalid character in class name: ${r}')
	}

	t.state = .after_tag
	t.str = strings.new_builder(100)
	return [t.token]
}

fn (mut t Tokenizer) attribute_name() []Token {
	r := t.consume() or {
		return t.eof()
	}

	if r in parser.alphahyphen {
		t.str.write_rune(r)
		return t.attribute_name()
	}

	if r == `(` {
		t.attr = t.str.str()
		t.str = strings.new_builder(100)
		t.state = .attribute_value
		return t.attribute_value()
	}

	println('Invalid character in attribute: ${r}')
	t.state = .after_tag
	t.str = strings.new_builder(100)
	return [t.token]
}

fn (mut t Tokenizer) attribute_value() []Token {
	r := t.consume() or {
		return t.eof()
	}

	// escape any character followed by backslash
	if r == `\\` {
		if next := t.next() {
			t.str.write_rune(next)
			t.pos++
		} else {
			t.str.write_rune(r)
		}
		return t.attribute_value()
	}

	if r == `)` {
		mut tag := t.token as TagToken
		tag.attributes[t.attr] = t.str.str()
		next := t.next() or {
			t.state = .eof
			return [Token(tag)]
		}
		if next == `$` {
			t.state = .attribute_name
			t.pos++
			t.token = tag
			return t.attribute_name()
		}
		t.state = .after_tag
		t.str = strings.new_builder(100)
		return [Token(tag)]
	}

	t.str.write_rune(r)
	return t.attribute_value()
}

fn (mut t Tokenizer) style_attribute() []Token {
	r := t.consume() or {
		return t.eof()
	}

	if r == `]` {
		t.token = StyleAttributeToken{
			pos: t.pos
			name: t.str.str()
		}
		t.state = .before_css_rule_name
		t.str = strings.new_builder(100)
		return [t.token]
	}

	if r !in parser.alphahyphen {
		println('Invalid character in style attribute: ${r}')
	}

	t.str.write_rune(r)
	return t.style_attribute()
}

fn (mut t Tokenizer) before_css_rule_name() []Token {
	r := t.consume() or {
		return t.eof()
	}

	if r in parser.whitespace {
		return t.before_css_rule_name()
	}

	if r in parser.alphahyphen {
		t.pos--
		t.state = .css_rule_name
		return t.css_rule_name()
	}

	if r == `:` {
		if t.str.len == 0 {
			println('CSS rule missing property name at position: ${t.pos}')
		}
		t.token = CSSRuleToken{pos: t.pos}
		t.state = .css_rule_value
		t.str = strings.new_builder(100)
		return t.css_rule_value()
	}

	if r == `[` {
		t.state = .style_attribute
		t.str = strings.new_builder(100)
		return t.style_attribute()
	}

	if r == `{` {
		t.state = .inner_text
		t.str = strings.new_builder(100)
		return t.inner_text()
	}

	if r == `}` {
		t.state = .before_css_rule_name
		return [CloseTagToken{
			pos: t.pos
		}]
	}

	println('Invalid character before CSS rule name or tag name: ${r}')
	return t.before_css_rule_name()
}

fn (mut t Tokenizer) css_rule_name() []Token {
	r := t.consume() or {
		return t.eof()
	}

	if r in parser.whitespace {
		return t.css_rule_name()
	}

	if r in parser.alphahyphen {
		t.str.write_rune(r)
		return t.css_rule_name()
	}

	if r == `:` {
		t.token = CSSRuleToken{
			pos: t.pos
			property: t.str.str()
		}
		t.str = strings.new_builder(100)
		t.state = .css_rule_value
		return t.css_rule_value()
	}

	// if this appears, we're starting a new tag instead of a CSS rule.
	// the function/state name should be updated to "css_rule_or_tag_name"
	if r == `{` {
		t.pos--
		t.token = TagToken{
			pos: t.pos
			name: t.str.str()
		}
		t.state = .after_tag
		t.str = strings.new_builder(100)
		return [t.token]
	}

	if r == `#` {
		t.token = TagToken{
			pos: t.pos
			name: t.str.str()
		}
		t.str = strings.new_builder(100)
		t.state = .tag_id
		return t.tag_id()
	}

	if r == `.` {
		t.token = TagToken{
			pos: t.pos
			name: t.str.str()
		}
		t.str = strings.new_builder(100)
		t.state = .tag_class
		return t.tag_class()
	}

	if r == `$` {
		t.token = TagToken{
			pos: t.pos
			name: t.str.str()
		}
		t.str = strings.new_builder(100)
		t.state = .attribute_name
		return t.attribute_name()
	}

	println('Invalid character in CSS rule name: ${r}')
	t.str.write_rune(r)
	return t.css_rule_name()
}

fn (mut t Tokenizer) css_rule_value() []Token {
	r := t.consume() or {
		return t.eof()
	}

	if r in parser.whitespace {
		return t.css_rule_value()
	}

	if r == `;` {
		mut rule := t.token as CSSRuleToken
		rule.value = t.str.str()
		t.str = strings.new_builder(100)
		t.state = .before_css_rule_name
		return [rule]
	}

	t.str.write_rune(r)
	return t.css_rule_value()
}

fn (mut t Tokenizer) inner_text() []Token {
	r := t.consume() or {
		return t.eof()
	}

	if r == `\\` {
		if next := t.next() {
			t.str.write_rune(next)
			t.pos++
		} else {
			t.str.write_rune(r)
		}
		return t.inner_text()
	}

	if r == `}` {
		t.state = .before_css_rule_name
		t.token = TextToken{
			pos: t.pos
			text: t.str.str()
		}
		t.str = strings.new_builder(100)
		return [t.token]
	}

	t.str.write_rune(r)
	return t.inner_text()
}

fn (mut t Tokenizer) eof() []Token {
	t.state = .eof
	return [Token(EOFToken(t.pos+1))]
}