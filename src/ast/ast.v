module ast

import strings

pub const const_tags_that_do_not_need_a_close_tag = ['area', 'base', 'br', 'embed', 'hr', 'img', 'input',
	'link', 'meta', 'param', 'source', 'track', 'wbr']

// Tree is the root of the AST.
[heap]
pub struct Tree {
__global:
	inner_text ?string
	comments   []Comment = []Comment{cap: 10}
	// This is the CSS that is added to the end of the <head> tag.
	global_css []&CSS  = []&CSS{cap: 100}
	children    []&Node = []&Node{cap: 15}
	head ?&Tag
	body ?&Tag
}

// html returns the HTML string representation of the tree.
pub fn (tree Tree) html() string {
	if mut head := tree.head {
		head.children << &Tag {
			name: 'style',
			// should be able to do this, but "css.str()" returns the reference address
			// When a reference invokes it's .str() method it prefaces the string value
			// with a `&` character; thus the `1..`.
			inner_text: tree.global_css.map(|css| css.str()[1..]).join('\n')
			attributes: [
				Attribute {
					name: 'type',
					value: 'text/css',
				},
			],
		}
	} else {
		eprintln('error: no <head> tag found in the CSSML file.')
		exit(1)
	}

	_ := tree.body or {
		eprintln('error: no <body> tag found in the CSSML file.')
		exit(1)
	}

	mut builder := strings.new_builder(2500)
	
	if tree.comments.len > 0 {
		for comment in tree.comments {
			builder.writeln(comment.html_recur(0))
		}
	}
	builder.writeln('<!DOCTYPE html>')
	for child in tree.children {
		builder.write_string(child.html_recur(0))
	}

	return builder.str()
}

// Node is a node in the AST.
pub interface Node {
	children []&Node
	html_recur(int) string
}

// Tag is an HTML tag in the AST.
[heap]
pub struct Tag {
__global:
	name       string
	inner_text ?string
	comments   []Comment   = []Comment{cap: 10}
	attributes []Attribute = []Attribute{cap: 15}
	children   []&Node     = []&Node{cap: 15}
}

// html returns the HTML string representation of the tag.
pub fn (tag Tag) html_recur(depth int) string {
	mut builder := strings.new_builder(250)

	// comments (if any)
	if tag.comments.len > 0 {
		for comment in tag.comments {
			builder.writeln(comment.html_recur(depth))
		}
	}

	// open tag (<some-tag attr="value">)
	builder.write_string('\t'.repeat(depth) + '<${tag.name}')
	for attribute in tag.attributes {
		builder.write_string(' ${attribute.name}')
		if attribute_value := attribute.value {
			builder.write_string('="${attribute_value}"')
		}
	}
	builder.write_u8(`>`)

	// open tags that don't required a close tag (<br>)
	if tag.name in const_tags_that_do_not_need_a_close_tag {
		return builder.str()
	}
	builder.write_u8(`\n`)

	// inner text (if any) with max 80 chars per line
	if inner_text := tag.inner_text {
		eighty_chars_max := split_text_into_80_char_lines(inner_text)
		for line in eighty_chars_max {
			builder.writeln('\t'.repeat(depth + 1) + line)
		}
	}

	// children tags (if any)
	for child in tag.children {
		builder.writeln(child.html_recur(depth + 1))
	}

	// close tag (</some-tag>)
	builder.write_string('\t'.repeat(depth) + '</${tag.name}>')

	return builder.str()
}

// Attribute is an attribute in an HTML tag.
pub struct Attribute {
__global:
	name  string
	value ?string
}

// Comment is an HTML comment in the AST.
pub type Comment = string

// html returns the HTML string representation of the comment.
[inline]
pub fn (comment Comment) html_recur(depth int) string {
	mut builder := strings.new_builder(200)

	// comment (<--CSSML-- some comment -->)
	if comment.len <= 80 {
		builder.write_string('\t'.repeat(depth) + '<!--CSSML-- ${comment} -->')
		return builder.str()
	}

	/* comment (if longer than 80 characters)
	 * <!--CSSML--
	 * 	  some comment
	 * -->
	 */
	max_80_chars := split_text_into_80_char_lines(comment)
	builder.writeln('\t'.repeat(depth) + '<!--CSSML--')
	for line in max_80_chars {
		builder.writeln('\t'.repeat(depth + 1) + line)
	}
	builder.write_string('\t'.repeat(depth) + '-->')

	return builder.str()
}

// split_text_into_80_char_lines splits the text into lines
// that are no longer than 80 characters.
fn split_text_into_80_char_lines(text string) []string {
	mut lines := []string{cap: 15}

	mut current_line := strings.new_builder(80)
	for character in text {
		if character == `\n` {
			lines << current_line.str()
			current_line = strings.new_builder(80)
		} else {
			current_line.write_u8(character)
		}
	}
	if current_line.len > 0 {
		lines << current_line.str()
	}

	return lines
}