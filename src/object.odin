package main;

import "core:fmt";
import "core:strings";

ObjectType :: enum {
	STRING,
}

Object :: struct {
	type: ObjectType,
	next: ^Object,
}

object_alloc :: proc($T: typeid, type: ObjectType) -> ^Object {
	when DEBUG do fmt.printf("[ALLOC] Allocating %v\n", type);
	obj := new(T);
	obj.type = type;

	obj.next = vm.objects;

	return obj;
}

obj_type    :: inline proc(v: Value) -> ObjectType do return as_obj(v).type;
is_obj_type :: inline proc(v: Value, type: ObjectType) -> bool 
	do return is_obj(v) && as_obj(v).type == type;

StringObject :: struct {
	using obj: Object,
	data: string,
	hash: u32,
}

as_string :: inline proc(v: Value) -> ^StringObject
	do return cast(^StringObject) as_obj(v);
is_string :: inline proc(v: Value) -> bool 
	do return is_obj_type(v, .STRING);


string_hash :: proc(str: string) -> u32{
	hash :u32 = 0x811C9DC5;
	for i := 0; i < len(str); i += 1 {
		hash ~= cast(u32) str[i];
		hash *= 0x1000193;
	}
	return hash;
}

string_alloc :: proc(str: string, hash: u32) -> ^StringObject {
	obj := cast(^StringObject) object_alloc(StringObject, ObjectType.STRING);
	obj.data = str;
	obj.hash = hash;
	vm.strings[hash] = obj;
	return obj;
}

string_copy :: proc(str: string) -> ^StringObject {
	hash := string_hash(str);
	elem, ok := vm.strings[hash];
	if ok {
		fmt.printf("Deduplicated '%v'.\n", str);
		return elem;
	}

	copied := strings.clone(str);
	return string_alloc(copied, hash);
}

string_take :: proc(str: string) -> ^StringObject {
	hash := string_hash(str);
	return string_alloc(str, hash);	
}

object_print :: proc(v: Value) {
	switch(obj_type(v)) {
	case .STRING:
		str := as_string(v).data;
		fmt.printf("%v", str);
	}
}

object_equals :: proc(a: Value, b: Value) -> bool {
	if obj_type(a) != obj_type(b) do return false;
	switch obj_type(a) {
		case .STRING: return as_string(a).data == as_string(b).data;
		case: return false;

	}
}

object_free :: proc(obj: ^Object) {
	switch obj.type {
	case .STRING:
		str := cast(^StringObject) obj;
		delete_string(str.data);
		free(str);
	}
}

object_free_all :: proc() {
	obj := vm.objects;
	for obj != nil {
		next := obj.next;
		object_free(obj);
		obj = obj.next;
	}
}
