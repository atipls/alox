package main;

import "core:fmt";

disasm_simple :: proc(name: string, offs: int) -> int {
	fmt.printf("%s\n", name);
	return offs + 1;
}

disasm_constant :: proc(name: string, using c: ^Chunk, offs: int) -> int {
	idx := code[offs + 1];
	fmt.printf("%-16s %4d '", name, idx);
	value_print(values[idx]);
	fmt.printf("'\n");
	return offs + 2;
}

disasm_byte :: proc(name: string, using c: ^Chunk, offs: int) -> int {
	idx := code[offs + 1];
	fmt.printf("%-16s %4d\n", name, idx);
	return offs + 2;	
}

disasm_jump :: proc(name: string, using c: ^Chunk, sign: int, offs: int) -> int {
	jump : int = cast(int) (code[offs + 1] << 8);
	jump      |= cast(int) (code[offs + 2]);
	fmt.printf("%-16s %04X -> %04X\n", name, offs, offs + 3 + sign * jump);
	return offs + 3;
}

disasm_instruction :: proc(using c: ^Chunk, offs: int) -> int {
	using OpCode;
	fmt.printf("%4X ", offs);

	if offs > 0 && lines[offs] == lines[offs - 1] {
		fmt.printf(" | "); 
	} else {
		fmt.printf("%4d ", lines[offs]); 
	} 

	instr := cast(OpCode) code[offs];
	switch instr {
	case OP_LDC: return disasm_constant("LDC", c, offs);
	case OP_LDN: return disasm_simple("LDN", offs);
	case OP_LDT: return disasm_simple("LDT", offs);
	case OP_LDF: return disasm_simple("LDF", offs);
	case OP_POP: return disasm_simple("POP", offs);
	case OP_DEG: return disasm_constant("DEG", c, offs);
	case OP_LDG: return disasm_constant("LDG", c, offs);
	case OP_STG: return disasm_constant("STG", c, offs);
	case OP_LDL: return disasm_byte("LDL", c, offs);
	case OP_STL: return disasm_byte("STL", c, offs);
	case OP_NOT: return disasm_simple("NOT", offs);
	case OP_NEG: return disasm_simple("NEG", offs);
	case OP_ADD: return disasm_simple("ADD", offs);
	case OP_SUB: return disasm_simple("SUB", offs);
	case OP_DIV: return disasm_simple("DIV", offs);
	case OP_MUL: return disasm_simple("MUL", offs);
	case OP_EQU: return disasm_simple("EQU", offs);
	case OP_GTT: return disasm_simple("GTT", offs);
	case OP_LTN: return disasm_simple("LTN", offs);
	case OP_JMP: return disasm_jump("JMP", c, 1, offs);
	case OP_JBK: return disasm_jump("JBK", c, -1, offs);
	case OP_JIF: return disasm_jump("JIF", c, 1, offs);
	case OP_PRN: return disasm_simple("PRN", offs);
	case OP_RET: return disasm_simple("RET", offs);
	}
	return offs + 1;
}

disasm :: proc(using c: ^Chunk, name: string) {
	fmt.printf("<=== chunk %s ===>\n", name);

	for i := 0; i < len(&code); {
		i = disasm_instruction(c, i);
	}
}