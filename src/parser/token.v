module parser

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
