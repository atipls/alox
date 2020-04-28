package main;

OpCode :: enum {
	OP_LDC,
	OP_LDN,
	OP_LDT,
	OP_LDF,
	
	OP_NOT,
	OP_NEG,
	OP_ADD,
	OP_SUB,
	OP_DIV,
	OP_MUL,

	OP_EQU,
	OP_GTT,
	OP_LTN,

	OP_PRN,

	OP_RET,
}