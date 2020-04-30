package main;

import "core:fmt";
import "core:os";

STACK_MAX :: 256;

VM :: struct {
	chunk: ^Chunk,
	stack: [STACK_MAX]Value,
	ip, sp: int,
	objects: ^Object,
	halt: bool,
	globals: map[u32]Value,
	strings: map[u32]^StringObject,
}
vm: VM;

vm_init :: proc() {
	vm.globals = make(map[u32]Value);
	vm.strings = make(map[u32]^StringObject);
}

vm_free :: proc() {
	object_free_all();
	delete(vm.globals);
	delete(vm.strings);
}

vm_error :: proc(msg: string, args: ..any) {
	fmt.printf("[vm error]: ");
	fmt.printf(msg, ..args);
  	line := vm.chunk.lines[vm.ip - 1];
	fmt.printf("[script]: line %d\n", line);
	vm.halt = true;
}

vm_execute :: proc(chunk: ^Chunk) -> bool {
	vm.chunk = chunk;
	vm.ip = 0;
	return vm_run();
}

@private
vm_run :: proc() -> bool {
	using vm;
	using OpCode;

	read :: proc() -> u8 {
		b := chunk.code[ip];
		ip += 1;
		return b;
	}
	constant :: proc() -> Value do return chunk.values[read()];
	read_string :: proc() -> ^StringObject do return as_string(constant());

	pop_numbers :: proc() -> (f64, f64) {
		if !is_number(peek()) 
		|| !is_number(peek(1)) {
			vm_error("operands must be numbers\n");
			return 0.0, 0.0;
		}

		b := as_number(pop());
		a := as_number(pop());
		return a, b;
	}

	is_falsey :: proc(v: Value) -> bool do return is_nil(v) || (is_bool(v) && !as_bool(v)); 

	concatenate :: proc() {
		b := as_string(pop()).data;
		a := as_string(pop()).data;
	
		final := string_take(fmt.tprintf("%v%v", a, b));
		push(obj_val(final));
	}

	when DEBUG do fmt.printf("<=== RUNNING VM ===>\n");
	for true {
		when DEBUG do disasm_instruction(chunk, ip);

		instr := cast(OpCode) read();
		switch instr {
		case OP_LDC: push(constant());
		case OP_LDN: push(nil_val());
		case OP_LDT: push(bool_val(true));
		case OP_LDF: push(bool_val(false));
		case OP_POP: pop();
		case OP_DEG: 
			using name := read_string();
			globals[hash] = peek();
			pop();
		case OP_LDG:
			using name := read_string();
			elem, ok := globals[hash];
			if !ok do vm_error("undeclared identifier: %v\n", data);
			push(elem);
		case OP_STG: 
			using name := read_string();
			if !(hash in globals) do vm_error("undeclared identifier: %v\n", data);
			globals[hash] = peek();
		case OP_NOT: push(bool_val(is_falsey(pop()))); 
		case OP_NEG:
			if !is_number(peek()) {
				vm_error("operand must be a number\n");
				break;
			}
		 	push(number_val(-as_number(pop())));
		// if there's a better way to do these, please tell me
		case OP_ADD:
			if (is_string(peek()) && is_string(peek(1))) {
				concatenate();
			} else {
				a, b := pop_numbers();
				push(number_val(a + b));
			}
		case OP_SUB:
			a, b := pop_numbers();
			push(number_val(a - b));
		case OP_DIV:
			a, b := pop_numbers();
			push(number_val(a / b));
		case OP_MUL: 
			a, b := pop_numbers();
			push(number_val(a * b));
		case OP_EQU: push(bool_val(value_equals(pop(), pop())));
		case OP_GTT:
			a, b := pop_numbers();
			push(bool_val(a > b));
		case OP_LTN:
			a, b := pop_numbers();
			push(bool_val(a < b));
		case OP_PRN:
			value_print(pop());
			fmt.println();
		case OP_RET:
			fmt.printf("\n");
			return true;
		}
		if halt do return false;
		when DEBUG { // after a successful execution
			fmt.printf("          ");
			for i := 0; i < sp; i += 1 do
				value_print(stack[i]);
			fmt.printf("\n");
		}
	}

	return true;
}

push :: proc(v: Value) {
	using vm;
	stack[sp] = v;
	sp += 1;
}

pop :: proc() -> Value {
	using vm;
	sp -= 1;
	v := stack[sp];
	return v;
}

@(private = "file")
peek :: proc(n := 0) -> Value 
	do return vm.stack[vm.sp - n - 1];