module parser

type Token = TagToken | CloseTagToken | TextToken | StyleAttributeToken | CSSRuleToken | CommentToken | EOFToken

struct TagToken {
mut:
	pos int
	name string
	attributes map[string]string
	id string
	class []string
}

struct CloseTagToken {
mut:
	pos int
}

struct TextToken {
mut:
	pos int
	text string
}

struct StyleAttributeToken {
mut:
	pos int
	name string
}

struct CSSRuleToken {
mut:
	pos int
	property string
	value string
}

struct CommentToken {
mut:
	pos int
	text string
}

type EOFToken = int