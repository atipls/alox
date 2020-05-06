package main;

OpCode :: enum {
	OP_LDC, // load constant
	OP_LDN, // load nil
	OP_LDT, // load true
	OP_LDF, // load false

	OP_POP, // pop value

	OP_DEG, // define global
	OP_LDG, // load global
	OP_STG, // store global

	OP_LDL, // load local
	OP_STL, // store local

	OP_NOT, // logical not
	OP_NEG, // negate value
	OP_ADD, // binary add
	OP_SUB, // binary sub
	OP_DIV, // binary div
	OP_MUL, // binary mul

	OP_EQU, // logical equals
	OP_GTT, // logical greater than
	OP_LTN, // logical less than

	OP_JMP, // unconditional jump
	OP_JBK, // unconditional jump backwards
	OP_JIF, // jump if false

	OP_PRN, // print value

	OP_RET, // return from function or from the interpreter
}