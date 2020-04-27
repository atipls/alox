package main;

Token :: struct {
	what: TokenType,
	data: string,
	line: int,
}

TokenType :: enum {
  // Single-character tokens.
  LEFT_PAREN, RIGHT_PAREN,
  LEFT_BRACE, RIGHT_BRACE,
  COMMA, DOT, MINUS, PLUS,
  SEMICOLON, SLASH, STAR,

  // One or two character tokens.
  BANG, BANG_EQUAL,
  EQUAL, EQUAL_EQUAL,
  GREATER, GREATER_EQUAL,
  LESS, LESS_EQUAL,

  // Literals.
  IDENTIFIER, STRING, NUMBER,

  // Keywords.
  AND, CLASS, ELSE, FALSE,
  FOR, FUN, IF, NIL, OR,
  PRINT, RETURN, SUPER, THIS,

  TRUE, VAR, WHILE,
  ERROR,
  EOF
}

token_new :: proc(what: TokenType, data: string = "", line := lex.line) -> Token {
	return Token {
		what = what,
		data = data,
		line = line,
	};
}

token_new_error :: proc(msg: string, line := lex.line) -> Token {
	return Token {
		what = TokenType.ERROR,
		data = msg,
		line = line,
	};
} 