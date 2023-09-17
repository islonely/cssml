module parser

import ast
import datatypes { Stack }
import strings
import term

// Parser is responsible for parsing the tokens emitted by the tokenizer.
struct Parser {
pub mut:
	tokenizer Tokenizer
	in_html bool
	current_styles strings.Builder = strings.new_builder(1000)
	css_mode ast.CSSMode = .global
	global_css []&ast.CSS = []&ast.CSS{cap: 100}
	css_stack []&ast.CSS = []&ast.CSS{cap: 100}
	tree &ast.Tree = &ast.Tree{}
	open_tags []&ast.Tag = []&ast.Tag{cap: 100}
}

// Parser.new instantiates a Parser with the given source CSSML.
pub fn Parser.new(src string) Parser {
	mut parser := Parser{
		tokenizer: Tokenizer.new(src)
	}
	return parser
}

// parse parses the source CSSML and stores the result in the Parser's tree.
pub fn (mut p Parser) parse() ! {
	mut tok := p.tokenizer.emit_token()!
	println(term.bright_blue('[Tokenization]'))
	for tok !is EOFToken {
		// println(tok)
		tok = p.tokenizer.emit_token()!
		println(tok)

		match mut tok {
			CommentToken {
				if p.open_tags.len > 0 {
					mut last := p.open_tags[p.open_tags.len - 1]
					last.comments << tok.text
					continue
				}
				p.tree.comments << tok.text
			}
			InnerTextToken {
				if p.open_tags.len > 0 {
					mut last := p.open_tags[p.open_tags.len - 1]
					last.inner_text = tok.text
					continue
				}
				p.tree.inner_text = tok.text
			}
			CSSRuleOpen {
				if tok.name == 'html' || (tok.direct_child && p.in_html) {
					p.in_html = true
					mut this_tag := &ast.Tag{name: tok.name}
					if p.open_tags.len > 0 {
						mut last := p.open_tags[p.open_tags.len - 1]
						last.children << this_tag
					} else {
						p.tree.children << this_tag
					}
					p.open_tags << this_tag

					if tok.id.len > 0 {
						this_tag.attributes << ast.Attribute{'id', tok.id}
					}
					if tok.classes.len > 0 {
						mut class_builder := strings.new_builder(250)
						for class in tok.classes {
							class_builder.write_string('${class} ')
						}
						this_tag.attributes << ast.Attribute{'class', class_builder.str()}
					}
					for name, val in tok.attributes {
						this_tag.attributes << ast.Attribute{name, val}
					}
				}

				p.css_stack << &ast.CSS{
					query_selector: tok.query_selector(QuerySelectorParams.all())
				}
			}
			CSSRule {
				mut last := p.css_stack[p.css_stack.len - 1]
				last.rules[tok.name] = tok.value
			}
			CSSRuleClose {
				if tok.is_also_tag_close {
					if p.open_tags.len > 0 {
						p.open_tags.pop()
					} else {
						return error('Invalid token: ${tok}')
					}
				}
				if p.css_stack.len == 0 {
					return error('Invalid token: ${tok}')
				}
				if p.css_stack.len == 1 {
					p.global_css << p.css_stack.pop()
					continue
				}
				popped := p.css_stack.pop()
				mut last := p.css_stack[p.css_stack.len - 1]
				last.embedded << popped
			}
			else {}
		}
	}
	println(tok.type_name())
}
