module parser

import ast
import strings
import term

// Parser is responsible for parsing the tokens emitted by the tokenizer.
struct Parser {
pub mut:
	tokenizer      Tokenizer
	in_html        bool
	current_styles strings.Builder  = strings.new_builder(2500)
	css_mode       ast.CSSMode      = .global
	global_css     []&ast.CSS       = []&ast.CSS{cap: 100}
	css_stack      []&ast.CSS       = []&ast.CSS{cap: 100}
	attributes     []CSSMLAttribute = []CSSMLAttribute{cap: 100}
	tree           &ast.Tree        = &ast.Tree{}
	open_tags      []&ast.Tag       = []&ast.Tag{cap: 100}
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
	for tok !is EOFToken {
		tok = p.tokenizer.emit_token()!

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
					mut this_tag := &ast.Tag{
						name: tok.name
					}
					if this_tag.name == 'head' {
						p.tree.head = this_tag
					} else if this_tag.name == 'body' {
						p.tree.body = this_tag
					}

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
				css_to_insert := p.css_stack[p.css_stack.len - 1] or {
					return error('unexpected token: ${tok}')
				}
				p.css_stack.pop()
				insert_css := fn [css_to_insert, mut p, tok] () ! {
					if p.css_stack.len == 0 {
						p.global_css << css_to_insert
						return
					}

					mut parent_css := p.css_stack[p.css_stack.len - 1] or {
						return error('unexpected token: ${tok}')
					}
					parent_css.embedded << css_to_insert
				}

				if tok.is_also_tag_close {
					mut last_tag := p.open_tags[p.open_tags.len - 1] or {
						return error('unexpected token: ${tok}')
					}
					p.open_tags.pop()

					if last_tag.cssml_attributes.len > 0 {
						attrib := last_tag.cssml_attributes.last()
						match attrib.name {
							'local' {
								last_tag.attributes << ast.Attribute{
									name:  'style'
									value: css_to_insert.inline_rules()
								}
							}
							else {
								insert_css()!
								println(term.bright_blue('[${attrib.name}]'))
							}
						}
						continue
					}
					insert_css()!
				} else {
					insert_css()!
				}
				// if tok.is_also_tag_close {
				// 	if p.open_tags.len > 0 {
				// 		p.open_tags.pop()
				// 	} else {
				// 		return error('Invalid token: ${tok}')
				// 	}
				// }
				// if p.css_stack.len == 0 {
				// 	return error('Invalid token: ${tok}')
				// }
				// if p.css_stack.len == 1 {
				// 	p.global_css << p.css_stack.pop()
				// 	continue
				// }
				// popped := p.css_stack.pop()
				// mut last := p.css_stack[p.css_stack.len - 1]
				// last.embedded << popped
			}
			CSSMLAttribute {
				if !p.in_html {
					return error('Unexpected token: ${tok}')
				}

				mut last_tag := p.open_tags.last()
				last_tag.cssml_attributes << ast.CSSMLAttribute{
					name: tok.name
					args: tok.vals
				}
			}
			EOFToken {
				break
			}
		}
	}
	// println(tok.type_name())
	p.tree.global_css = p.global_css
	p.global_css.clear()
}
