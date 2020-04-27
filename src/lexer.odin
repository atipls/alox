package main;

import "core:fmt";
import "core:strings";

Lexer :: struct {
	data: string,
	idx: int,
	line: int,
	builder: strings.Builder,
}

lex: Lexer;

lex_init :: proc(data: string) {
	lex.data = data;
	lex.line = 1;
	lex.builder = strings.make_builder();
}
lex_free :: proc() { strings.destroy_builder(&lex.builder); }

get :: proc(n :int = 0) -> u8 {
	using lex;
	ret := data[idx + n];
	idx += 1; 
	return ret;
}
peek :: proc() -> u8 do return end() ? 0 : lex.data[lex.idx];
next :: proc() -> u8 {
	if end() do return 0;
	return lex.data[lex.idx];
}
end :: proc() -> bool do return lex.idx >= len(lex.data);
match :: proc(c: u8) -> bool {
  if end() do return false;
  if peek() != c do return false;

  lex.idx += 1;
  return true;
}

eat :: proc() -> u8 {
	c := get();
	strings.write_byte(&lex.builder, c);
	return c;
}

get_built :: proc() -> string {
	str := strings.to_string(lex.builder);
	strings.reset_builder(&lex.builder);
	return str;
}

skip_writespace_and_comments :: proc() {
	for true {
    	c := peek();
    	switch c {
		case ' ': fallthrough;
      	case '\r': fallthrough;
      	case '\t':
        	get();
        case '\n':
        	lex.line += 1;
        	get();
        case '/':
        	if next() == '/' { 
        		for peek() != '\n' && !end() do get();
        	} else do return;
		case: return;
    	}
  	}
}

identifier_type :: proc(str: string) -> TokenType {
	using TokenType;
	switch str {
	case "and": return AND;
	case "class": return CLASS;
	case "else": return ELSE;
	case "false": return FALSE;
	case "for": return FOR;
	case "fun": return FUN;
	case "if": return IF;
	case "nil": return NIL;
	case "or": return OR;
	case "print": return PRINT;
	case "return": return RETURN;
	case "super": return SUPER;
	case "this": return THIS;
	case "true": return TRUE;
	case "var": return VAR;
	case "while": return WHILE;
	}

	return IDENTIFIER;
}

get_token :: proc() -> Token {
	using TokenType;
	
	skip_writespace_and_comments();
	
	if end() do return token_new(EOF, "");
	
	if is_alpha(peek()) do return get_identifier();
	if is_digit(peek()) do return get_number();

	c := get();
	switch c {
    case '(': return token_new(LEFT_PAREN);
    case ')': return token_new(RIGHT_PAREN);
    case '{': return token_new(LEFT_BRACE);
    case '}': return token_new(RIGHT_BRACE);
    case ';': return token_new(SEMICOLON);
    case ',': return token_new(COMMA);
    case '.': return token_new(DOT);
    case '-': return token_new(MINUS);
    case '+': return token_new(PLUS);
    case '/': return token_new(SLASH);
    case '*': return token_new(STAR);
	case '!': return token_new(match('=') ? BANG_EQUAL : BANG);
    case '=': return token_new(match('=') ? EQUAL_EQUAL : EQUAL);
    case '<': return token_new(match('=') ? LESS_EQUAL : LESS);
    case '>': return token_new(match('=') ? GREATER_EQUAL : GREATER);
    case '"': return get_string();
  	}

	return token_new_error("unexpected character");
}

get_string :: proc() -> Token {
	using lex;
	for peek() != '"' && !end() {
		c := eat();	
		if c == '\n' do line += 1;
	}

	if end() do return token_new_error("unterminated string");
	
	get(); // closing quote
	return token_new(TokenType.STRING, get_built());
}

get_number :: proc() -> Token {
	using lex;
	for is_digit(peek()) do eat();

 	if peek() == '.' && is_digit(next()) {
	    eat();                    
    	for is_digit(peek()) do eat();       
  	}
	return token_new(TokenType.NUMBER, get_built());
}

get_identifier :: proc() -> Token {
	for is_alpha(peek()) || is_digit(peek()) do eat();
	str := get_built();
	return token_new(identifier_type(str), str);
}

is_digit :: proc(c: u8) -> bool do return c >= '0' && c <= '9';
is_alpha :: proc(c: u8) -> bool do return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
