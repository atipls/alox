package main;

import "core:fmt";
import "core:os";

DEBUG :: true;

interpret :: proc(data: string) -> bool {
	success, chunk := compile(data);
	defer chunk_free(&chunk);
	if !success do return false;
	return vm_execute(&chunk);
}

main :: proc() {
	vm_init();

	filename := "test.at";
	switch len(os.args) {
	case 1: // repl();
	case 2: filename = os.args[1];
	case: fmt.panicf("usage: acc [path]");
	}

	data, success := os.read_entire_file(filename);
	if !success {
		fmt.panicf("cannot read file %v.\n", filename);
		}
	file := string(data);
	interpret(file);

	vm_free();
}
