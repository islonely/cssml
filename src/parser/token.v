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
	| CloseTagToken
	| CommentToken
	| EOFToken
	| StyleAttributeToken
	| TagToken
	| TextToken

// TagToken represents an HTML tag: <html>
struct TagToken {
mut:
	pos        int
	len        int
	name       string
	attributes map[string]string
	id         string
	class      []string
}

// CloseTagToken represents an HTML end tag: </html>
struct CloseTagToken {
mut:
	pos int
	len int
}

// TextToken represents a string of text.
struct TextToken {
mut:
	pos  int
	len  int
	text string
}

// StyleAttributeToken represents a CSSML style attribute: [local]
struct StyleAttributeToken {
mut:
	pos  int
	len  int
	name string
}

// CSSRuleOpen represents 'div#id.class {'
struct CSSRuleOpen {
mut:
	pos            int
	len            int
	query_selector string
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
