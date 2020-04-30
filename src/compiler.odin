package main;

import "core:fmt";
import "core:strconv";

LEX_DEBUG :: false;

Parser :: struct {
	cur, prev: Token,
	had_error, panic: bool,
}

Precedence :: enum {
	NONE,
	ASSIGNMENT,
	OR,
	AND,
	EQUALITY,
	COMPARISON,
	TERM,
	FACTOR,
	UNARY,
	CALL,
	PRIMARY
}

ParseRule :: struct {
	prefix: proc(),
	infix: proc(),
	prec: Precedence,
}

parser: Parser;
chunk: ^Chunk;
rules: map[TokenType]ParseRule;

error_at_current :: proc(msg: string) do error_at(&parser.cur, msg); 
error :: proc(msg: string) do error_at(&parser.prev, msg);
error_at :: proc(token: ^Token, msg: string) { 
	if parser.panic do return;
	parser.panic = true;

  	fmt.eprintf("[line %d] error ", token.line);
  	
  	#partial switch token.what {
  	case TokenType.EOF: fmt.eprintf("at eof");
  	case TokenType.ERROR:
  	case: fmt.eprintf("at '%s' (%v)", token.data, token.what);
	}

  	fmt.eprintf(": %s\n", msg);
  	parser.had_error = true;
}
synchronize :: proc() {
	using parser;
	for cur.what != .EOF {
		if prev.what == .SEMICOLON do return;

		#partial switch cur.what {
		case .CLASS, .FUN, .VAR, .FOR, .IF,
			 .WHILE, .PRINT, .RETURN:
			return;
		case: // do nothing
		}
		advance();
	}
}

current_chunk :: inline proc() -> ^Chunk do return chunk;

compile :: proc(data: string) -> (bool, Chunk) {
	using TokenType;
	lex_init(data);
	ch := chunk_new();
	chunk = &ch;
	init_rules();

	when LEX_DEBUG {
		line := -1;
		for true {
			token := get_token();
			if (token.line != line) {
				fmt.printf("%4d ", token.line);
				line = token.line;
			} else {
				fmt.printf("   | ");
			}
			fmt.printf("%v '%v'\n", token.what, token.data); 
			if token.what == EOF do break;
		}
	} else {
		advance();
		
		for !match(EOF) {
			declaration();
		}

		consume(EOF, "end of file expected.");
		compile_end();
		if !parser.had_error do disasm(&ch, "compiled");
	}

  	lex_free();
  	return !parser.had_error, ch;
}

advance :: proc() {
	using parser;
	using TokenType;

	prev = cur;
	for true {
		cur = get_token();
		if cur.what == ERROR {
			error_at_current(cur.data);
		}
		break;
	}
}

consume :: proc(what: TokenType, msg: string) {
	if parser.cur.what == what {
		advance();
		return;
	}
	error_at_current(msg);
}

check :: proc(what: TokenType) -> bool {
	return parser.cur.what == what;
}

@(private = "file")
match :: proc(what: TokenType) -> bool {
	if !check(what) do return false;
	advance();
	return true;
}

compile_end :: proc() do emit_return();

emit_byte :: proc(b: u8) do	chunk_add(current_chunk(), b, parser.prev.line);
emit_opcode :: proc(op: OpCode) do chunk_add(current_chunk(), op, parser.prev.line);
emit_twoop :: proc(op1: OpCode, op2: OpCode) {
	emit_opcode(op1);
	emit_opcode(op2);
}
emit_instr :: proc(op: OpCode, b: u8) {
	emit_opcode(op);
	emit_byte(b);
}
emit :: proc {emit_byte, emit_opcode, emit_twoop, emit_instr};

emit_return :: proc() do emit(OpCode.OP_RET);
emit_const  :: proc(val: Value) do emit(OpCode.OP_LDC, make_constant(val));
emit_global :: proc(global: u8) do emit(OpCode.OP_STG, global);

make_constant :: proc(val: Value) -> u8 {
	index := value_add(current_chunk(), val);
	if index > 0xFF {
		error("too many constants in the chunk.");
		return 0;
	}
	return cast(u8) index;
}

expression :: proc() {
	precedence(.ASSIGNMENT);
}

var_declaration :: proc() {
	global := parse_variable("variable name expected.");
	if match(.EQUAL) {
		expression();
	} else do emit(OpCode.OP_LDN);

	consume(.SEMICOLON, "expected ';' after variable declaration.");

	emit_global(global);
}

declaration :: proc() {
	if match(.VAR) do var_declaration();
	else do statement();

	if parser.panic do synchronize();
}

statement :: proc() {
	if match(.PRINT) do print_statement();
	else do expression_statement();
}

print_statement :: proc() {
	using OpCode;
	expression();
	consume(.SEMICOLON, "expected ';'.");
	emit(OP_PRN);
}

expression_statement :: proc() {
	using OpCode;
	expression();
	consume(.SEMICOLON, "expected ';'.");
	emit(OP_POP);
}

grouping :: proc() {
	expression();
	consume(.RIGHT_PAREN, "expected ')'.");
}

unary :: proc() {
	using TokenType;
	using OpCode;

	what := parser.prev.what;

	precedence(.UNARY);

	#partial switch what {
	case MINUS:	emit(OP_NEG);
	case BANG:	emit(OP_NOT);
	case: assert(false); 
	}
}

binary :: proc() {
	using TokenType;
	using OpCode;

	what := parser.prev.what;

	rule := get_rule(what);
	precedence(cast(Precedence)(int(rule.prec) + 1));

	#partial switch what {
	case PLUS:			emit(OP_ADD);
	case MINUS:			emit(OP_SUB);
	case STAR:			emit(OP_MUL);
	case SLASH:			emit(OP_DIV);
	case BANG_EQUAL:	emit(OP_EQU, OP_NOT);
	case EQUAL_EQUAL:	emit(OP_EQU);
    case GREATER:		emit(OP_GTT);
    case GREATER_EQUAL:	emit(OP_LTN, OP_NOT);
    case LESS: 			emit(OP_LTN);
    case LESS_EQUAL:	emit(OP_GTT, OP_NOT);
	case: assert(false); 
	}
}

literal :: proc() {
	using TokenType;
	using OpCode;

	#partial switch parser.prev.what {
	case NIL:	emit(OP_LDN);
	case TRUE:	emit(OP_LDT);
	case FALSE:	emit(OP_LDF);
	case: assert(false);
	}
}

precedence :: proc(prec: Precedence) {
	advance();
	prefix := get_rule(parser.prev.what).prefix;
	if prefix == nil {
		error("expected expression");
		return;
	}
	prefix();

	for prec <= get_rule(parser.cur.what).prec {
		advance();
		get_rule(parser.prev.what).infix();
	}
}

get_rule :: proc(what: TokenType) -> ParseRule do return rules[what];

init_rules :: proc() {
	using TokenType;
	rules = { 
  		LEFT_PAREN    = { grouping, nil,     .NONE },
  		RIGHT_PAREN   = { nil,      nil,     .NONE },
  		LEFT_BRACE    = { nil,      nil,     .NONE },
  		RIGHT_BRACE   = { nil,      nil,     .NONE },
  		COMMA         = { nil,      nil,     .NONE },
  		DOT           = { nil,      nil,     .NONE },
  		MINUS         = { unary,    binary,  .TERM },
  		PLUS          = { nil,      binary,  .TERM },
  		SEMICOLON     = { nil,      nil,     .NONE },
  		SLASH         = { nil,      binary,  .FACTOR },
  		STAR          = { nil,      binary,  .FACTOR },
  		BANG          = { unary,    nil,     .NONE },
  		BANG_EQUAL    = { nil,      binary,  .EQUALITY },
  		EQUAL         = { nil,      binary,  .COMPARISON },
  		EQUAL_EQUAL   = { nil,      binary,  .COMPARISON },
  		GREATER       = { nil,      binary,  .COMPARISON },
  		GREATER_EQUAL = { nil,      binary,  .COMPARISON },
  		LESS          = { nil,      binary,  .COMPARISON },
  		LESS_EQUAL    = { nil,      binary,  .COMPARISON },
  		IDENTIFIER    = { nil,      binary,  .NONE },
  		STRING        = { constant, nil,     .NONE },
  		NUMBER        = { number,   nil,     .NONE },
  		AND           = { nil,      nil,     .NONE },
  		CLASS         = { nil,      nil,     .NONE },
  		ELSE          = { nil,      nil,     .NONE },
  		FALSE         = { literal,  nil,     .NONE },
  		FOR           = { nil,      nil,     .NONE },
  		FUN           = { nil,      nil,     .NONE },
  		IF            = { nil,      nil,     .NONE },
  		NIL           = { literal,  nil,     .NONE },
  		OR            = { nil,      nil,     .NONE },
  		PRINT         = { nil,      nil,     .NONE },
  		RETURN        = { nil,      nil,     .NONE },
		SUPER         = { nil,      nil,     .NONE },     
  		THIS          = { nil,      nil,     .NONE },
		TRUE          = { literal,  nil,     .NONE },     
  		VAR           = { nil,      nil,     .NONE },
  		WHILE         = { nil,      nil,     .NONE },
  		ERROR         = { nil,      nil,     .NONE },
  		EOF           = { nil,      nil,     .NONE },
  	};          
}

parse_variable :: proc(msg: string) -> u8 {
	consume(.IDENTIFIER, msg);
	return constant_ident(&parser.prev);
}

number :: proc() {
	value := strconv.parse_f64(parser.prev.data);
	emit_const(number_val(value));
}

constant :: proc() {
	object := string_copy(parser.prev.data);
	emit_const(obj_val(object));
}

constant_ident :: proc(tok: ^Token) -> u8 {
	return make_constant(obj_val(string_copy(tok.data)));
}