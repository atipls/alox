package main;

import "core:fmt";
import "core:strconv";

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
	prefix: proc(bool),
	infix: proc(bool),
	prec: Precedence,
}

Local :: struct {
	name: Token,
	depth: int,
}

Compiler :: struct {
	locals: [STACK_MAX]Local,
	local_count, depth: int,
}

parser: Parser;
chunk: ^Chunk;
rules: map[TokenType]ParseRule;
compiler: ^Compiler;

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
	
	c: Compiler;
	compiler_init(&c);

	advance();

	for !match(EOF) {
		declaration();
	}

	consume(EOF, "end of file expected.");
	compiler_end();
	if !parser.had_error do disasm(&ch, "compiled");

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

compiler_init :: proc(c: ^Compiler) do compiler = c;
compiler_end :: proc() do emit_return();
begin_scope :: proc() do compiler.depth += 1;
end_scope :: proc() {
	using compiler;
	using OpCode;

	depth -= 1;

	for local_count > 0 && locals[local_count - 1].depth > depth {
		emit(OP_POP);
		local_count -= 1;
	}
}

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
emit_global :: proc(global: u8) {
	if compiler.depth > 0 {
		init_variable();
		return;
	}

	emit(OpCode.OP_DEG, global);
}
emit_jump :: proc(op: OpCode) -> u16 {
	emit(op);
	emit(0xFF);
	emit(0xFF);
	return cast(u16) len(current_chunk().code) - 2;
}
patch_jump :: proc(addr: u16) {
	jump := cast(u16) len(current_chunk().code) - addr - 2;
	if jump > 0xFFFF {
		error("code is too big to jump over.");
	}

	current_chunk().code[addr]     = cast(u8) ((jump >> 8) & 0xFF);
	current_chunk().code[addr + 1] = cast(u8) (jump & 0xFF);
}

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

block :: proc() {                                     
  	for !check(.RIGHT_BRACE) && !check(.EOF) {
		declaration();                                        
	}
	consume(.RIGHT_BRACE, "expected '}' after block.");  
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
	switch {
	case match(.PRINT): print_statement();
	case match(.IF): if_statement();
	case match(.LEFT_BRACE): 
		begin_scope();
		block();
		end_scope();
	case: expression_statement();
	}
}

print_statement :: proc() {
	using OpCode;
	expression();
	consume(.SEMICOLON, "expected ';'.");
	emit(OP_PRN);
}

if_statement :: proc() {
	consume(.LEFT_PAREN, "expected '(' after 'if'.");
	expression();
	consume(.RIGHT_PAREN, "expected ')' after 'if expression'.");

	then := emit_jump(.OP_JIF);
	emit(OpCode.OP_POP);
	statement();

	elsejmp := emit_jump(.OP_JMP);
	patch_jump(then);
	emit(OpCode.OP_POP);

	if match(.ELSE) do statement();
	patch_jump(elsejmp);
}

expression_statement :: proc() {
	using OpCode;
	expression();
	consume(.SEMICOLON, "expected ';'.");
	emit(OP_POP);
}

grouping :: proc(can_assign: bool) {
	expression();
	consume(.RIGHT_PAREN, "expected ')'.");
}

unary :: proc(can_assign: bool) {
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

binary :: proc(can_assign: bool) {
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

literal :: proc(can_assign: bool) {
	using TokenType;
	using OpCode;

	#partial switch parser.prev.what {
	case NIL:	emit(OP_LDN);
	case TRUE:	emit(OP_LDT);
	case FALSE:	emit(OP_LDF);
	case: assert(false);
	}
}

and :: proc(can_assign: bool) {
	jump := emit_jump(.OP_JIF);

	emit(OpCode.OP_POP);
	precedence(.AND);

	patch_jump(jump);
}

or :: proc(can_assign: bool) {
	elsejmp := emit_jump(.OP_JIF);
	endjmp  := emit_jump(.OP_JMP);

	patch_jump(elsejmp);
	emit(OpCode.OP_POP);

	precedence(.OR);
	patch_jump(endjmp);
}

precedence :: proc(prec: Precedence) {
	advance();
	prefix := get_rule(parser.prev.what).prefix;
	if prefix == nil {
		error("expected expression");
		return;
	}
	can_assign := prec <= .ASSIGNMENT;
	prefix(can_assign);

	for prec <= get_rule(parser.cur.what).prec {
		advance();
		get_rule(parser.prev.what).infix(can_assign);
	}

	if can_assign && match(.EQUAL) {
		error("invalid assignment target");
		return;
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
  		IDENTIFIER    = { variable, binary,  .NONE },
  		STRING        = { constant, nil,     .NONE },
  		NUMBER        = { number,   nil,     .NONE },
  		AND           = { nil,      and,     .AND  },
  		CLASS         = { nil,      nil,     .NONE },
  		ELSE          = { nil,      nil,     .NONE },
  		FALSE         = { literal,  nil,     .NONE },
  		FOR           = { nil,      nil,     .NONE },
  		FUN           = { nil,      nil,     .NONE },
  		IF            = { nil,      nil,     .NONE },
  		NIL           = { literal,  nil,     .NONE },
  		OR            = { nil,      or,      .OR   },
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

	declare_variable();
	if compiler.depth > 0 do return 0;

	return constant_ident(&parser.prev);
}

init_variable :: proc() {
	using compiler;
	locals[local_count - 1].depth = depth;
}

number :: proc(can_assign: bool) {
	value := strconv.parse_f64(parser.prev.data);
	emit_const(number_val(value));
}

constant :: proc(can_assign: bool) {
	object := string_copy(parser.prev.data);
	emit_const(obj_val(object));
}

variable :: proc(can_assign: bool) {
	named_variable(&parser.prev, can_assign);
}

named_variable :: proc(name: ^Token, can_assign: bool) {
	using OpCode;

	get_op := OP_LDG;
	set_op := OP_STG;

	index, resolved := resolve_local(name);
	if !resolved {
		index = constant_ident(name);
	} else {
		get_op = OP_LDL;
		set_op = OP_STL;
	}

	if can_assign && match(.EQUAL) {
		expression();
		emit(set_op, index);
	} else do emit(get_op, index);
}

constant_ident :: proc(tok: ^Token) -> u8 {
	return make_constant(obj_val(string_copy(tok.data)));
}

add_local :: proc(name: ^Token) {
	using compiler;
	if local_count == STACK_MAX {
		error("too many local variables.");
		return;
	}

	local := &locals[local_count];
	local_count += 1;
	local.name = name^;
	local.depth = -1;
}

resolve_local :: proc(name: ^Token) -> (u8, bool) {
	for i := compiler.local_count - 1; i >= 0; i -= 1 {
		local := &compiler.locals[i];
		if name.data == local.name.data {
			if local.depth == -1 {
				error("cannot assign variable to itself.");
			}
			return cast(u8) i, true; 
		}
	}
	return 0, false;
}

declare_variable :: proc() {
	if compiler.depth == 0 do return;
	name := &parser.prev;

	for i := compiler.local_count - 1; i >= 0; i -= 1 {
		local := &compiler.locals[i];
		if local.depth != -1 && local.depth < compiler.depth {
			break;
		}

		if name.data == local.name.data {
			error("variable already declared in this scope.");
		}
	}

	add_local(name);
}