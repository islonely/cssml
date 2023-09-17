module parser

import strings

// Locatable is something that can be found in the source
// rune array.
interface Locatable {
	pos int
	len int
}

// Token is the items that the parser turns into a tree.
type Token = CSSRule
	| CSSRuleClose
	| CSSRuleOpen
	| CommentToken
	| EOFToken
	| CSSMLAttribute
	| InnerTextToken


// InnerTextToken represents a string of text.
struct InnerTextToken {
mut:
	pos  int
	len  int
	text string
}

// CSSAttribute represents a CSSML style attribute: [local], [id; class], etc.
struct CSSMLAttribute {
mut:
	pos  int
	len  int
	name string
	vals []string = []string{cap: 10}
}

// CSSRuleOpen represents 'div#id.class {'
struct CSSRuleOpen {
mut:
	pos            int
	len            int
	direct_child bool
	name string
	id string
	classes []string = []string{cap: 10}
	attributes map[string]?string
	pseudo struct {
	mut:
		classes []string = []string{cap: 5}
		elements []string = []string{cap: 1}
	}
}

// QuerySelectorParams is a struct that can be passed to
// CSSRuleOpen.query_selector to determine which parts of the
// selector string to include.
[params]
struct QuerySelectorParams {
	name bool
	id bool
	classes bool
	attributes bool
	pseudo struct {
		classes bool
		elements bool
	}
}

// QuerySelectorParams.all returns a QuerySelectorParams with all fields set to true.
[inline]
fn QuerySelectorParams.all() QuerySelectorParams {
	return QuerySelectorParams{
		name: true,
		id: true,
		classes: true,
		attributes: true,
		pseudo: struct {
			classes: true,
			elements: true,
		},
	}
}

// query_selector returns a CSS selector string for the rule.
fn (rule_open CSSRuleOpen) query_selector(params QuerySelectorParams) string {
	mut qs := strings.new_builder(200)
	qs.write_string(if rule_open.direct_child { '> ' } else { '' })
	if params.name {
		qs.write_string(rule_open.name)
	}
	if params.id && rule_open.id.len > 0 {
		qs.write_string('#${rule_open.id}')
	}
	if params.classes {
		for class in rule_open.classes {
			qs.write_string('.${class}')
		}
	}
	if params.attributes {
		for attr_name, opt_attr_val in rule_open.attributes {
			qs.write_string('[')
			qs.write_string(attr_name)
			if attr_val := opt_attr_val {
				qs.write_string('=')
				qs.write_string('"${attr_val}"')
			}
			qs.write_string(']')
		}
	}
	if params.pseudo.classes {
		for pseudo_class in rule_open.pseudo.classes {
			qs.write_string(':${pseudo_class}')
		}
	}
	if params.pseudo.elements {
		for pseudo_element in rule_open.pseudo.elements {
			qs.write_string('::${pseudo_element}')
		}
	}
	return qs.str()
}

struct CSSRule {
mut:
	pos   int
	len   int
	name  string
	value string
}

// CSSRuleClose represents a closing bracket '}' for CSS rules.
struct CSSRuleClose {
mut:
	pos int
	len int
	is_also_tag_close bool
}

// CommentToken represents an HTML comment.
struct CommentToken {
mut:
	pos  int
	len  int
	text string
}

// EOFToken represents the end of file.
struct EOFToken {
	pos int
	len int
}
