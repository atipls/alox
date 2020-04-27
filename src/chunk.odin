package main;


Chunk :: struct {
	code: [dynamic]u8,
	values: [dynamic]Value,
	lines: [dynamic]int,
}

@private 
grow_capacity :: inline proc(cap: int) -> int do return cap < 8 ? 8 : cap * 2;

chunk_new :: proc() -> Chunk {
	return Chunk {
		code = make([dynamic]u8),
		values = make([dynamic]Value),
		lines = make([dynamic]int),
	};
}

chunk_free :: proc(using c: ^Chunk) {
	clear(&code);
	clear(&values);
	delete(code);
	delete(values);
}

chunk_add_byte :: proc(using c: ^Chunk, b: u8, line: int) {
	append(&code, b);
	append(&lines, line);
}
chunk_add_opcode :: proc(using c: ^Chunk, op: OpCode, line: int) {
	append(&code, cast(u8) op);
	append(&lines, line);
}
chunk_add_constant ::proc(using c: ^Chunk, v: Value, line: int) {
	idx := cast(u8) value_add(c, v);
	chunk_add_opcode(c, OpCode.OP_LDC, line);
	chunk_add_byte(c, idx, line);
}

chunk_add :: proc {chunk_add_byte, chunk_add_opcode, chunk_add_constant};