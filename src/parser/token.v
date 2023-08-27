module parser

type Token = TagToken | TextToken | CSSRuleToken | CommentToken | EOFToken

struct TagToken {
mut:
	name string
	inner_text string
	attributes map[string]string
	id string
	class []string
}

struct TextToken {
mut:
	text string
}

struct CSSRuleToken {
mut:
	property string
	value string
}

struct CommentToken {
mut:
	text string
}

type EOFToken = u8