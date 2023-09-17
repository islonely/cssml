module ast

import strings

// CSSMode is the mode of the current CSS rules.
pub enum CSSMode {
	// global means that the CSS rules encountered will be
	// appended to the <style> tag in the <head> tag.
	global
	// local means that the CSS rules encountered will be
	// a part of the `style=""` attribute of the current
	// element.
	local
}

// CSSGlobalMode is how the CSS query selector will be
// generated.
[flag]
pub enum CSSGlobalMode {
	id
	class
	attributes
	pseudo_class
	pseudo_element
}

// CSS is a struct that represents a CSS block and its
// nested CSS blocks.
pub struct CSS {
__global:
	query_selector string
	rules map[string]string
	embedded []&CSS = []&CSS{cap: 10}
}

// str returns the CSS block as a string.
pub fn (css CSS) str() string {
	mut sb := strings.new_builder(5000)
	sb.write_string(css.str_recer(0))
	return sb.str()
}

// str_recer is a recursive function that returns the CSS
// block as a string.
fn (css CSS) str_recer(depth int) string {
	mut sb := strings.new_builder(1000)
	sb.write_string('${css.query_selector} {')
	if css.rules.len > 0 {
		sb.write_string('\n')
	}
	for name, val in css.rules {
		sb.write_string('\t'.repeat(depth + 1))
		sb.writeln('${name.trim_space()}: ${val.trim_space()};')
	}
	if css.embedded.len > 0 {
		sb.write_string('\n')
	}
	for embed in css.embedded {
		sb.write_string('\t'.repeat(depth + 1))
		sb.write_string(embed.str_recer(depth + 1))
	}
	sb.write_string('\t'.repeat(depth))
	sb.writeln('}')
	return sb.str()
}