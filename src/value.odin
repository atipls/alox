package main;

import "core:fmt";

ValueType :: enum {
	NUMBER,
	BOOL,
	NIL,
	OBJ,
}

Value :: struct {
	type: ValueType,
	using as: struct #raw_union {
		_bool: bool,
		_num: f64,
		_obj: ^Object,
	}
}

number_val :: inline proc(val: f64) -> Value {
	v := Value { type = .NUMBER };
	v.as._num = val;
	return v;
}
bool_val :: inline proc(val: bool) -> Value {
	v := Value { type = .BOOL };
	v.as._bool = val;
	return v;
}
nil_val :: inline proc() -> Value do return Value { type = .NIL };
obj_val :: inline proc(val: ^Object) -> Value {
	v := Value { type = .OBJ };
	v.as._obj = val;
	return v;
}
as_number :: inline proc(using v: Value) -> f64		do return as._num;
as_bool   :: inline proc(using v: Value) -> bool	do return as._bool;
as_obj    :: inline proc(using v: Value) -> ^Object do return as._obj;
is_number :: inline proc(using v: Value) -> bool	do return type == .NUMBER;
is_bool   :: inline proc(using v: Value) -> bool	do return type == .BOOL;
is_nil    :: inline proc(using v: Value) -> bool	do return type == .NIL;
is_obj    :: inline proc(using v: Value) -> bool	do return type == .OBJ;


value_add :: proc(using c: ^Chunk, v: Value) -> int {
	append(&values, v);
	return len(&values) - 1;
}

value_print :: proc(v: Value) {
	switch {
	case is_number(v):	fmt.printf("%v", as_number(v));
	case is_bool(v):	fmt.printf("%v", as_bool(v));
	case is_obj(v):		object_print(v); 
	case is_nil(v): 	fmt.printf("nil");
	case:				
	}
}

value_equals :: proc(a: Value, b: Value) -> bool {
	if a.type != b.type do return false;

	switch {
	case is_number(a): 	return as_number(a) == as_number(b);
	case is_bool(a): 	return as_bool(a) == as_bool(b);
	case is_nil(a): 	return true;
	case is_obj(a):		return object_equals(a, b);
	case: 				return false;
	}
}