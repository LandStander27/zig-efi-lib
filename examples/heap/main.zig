const std = @import("std");
const efi = @import("efi");

fn entry() !void {
	try efi.io.init_io();
	
	const alloc = efi.heap.Allocator.init();
	var arr = try alloc.alloc(usize, 10);
	defer alloc.free(arr);
	
	for (0..arr.len) |i| {
		arr[i] = i+1;
	}
	try efi.io.println("Numbers 1-10 using manual allocated slice: {any}", .{arr});
	
	var arr2 = try efi.array.ArrayList(usize).init(alloc);
	defer arr2.deinit();
	
	for (0..10) |i| {
		try arr2.append(i+1);
	}
	try efi.io.println("Numbers 1-10 using auto allocated slice: {any}", .{arr2.items});
	
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
	efi.io.puts("KERNEL PANIC: ");
	efi.io.puts(msg);
	efi.io.puts("\n");
	efi.io.puts("OBJECTS ON HEAP: ");
	efi.io.print("{d}\n", .{efi.heap.amount}) catch {
		efi.io.puts("COULD NOT PRINT OBJECTS ON HEAP\n");
	};
	
	while (true) {
		asm volatile ("hlt");
	}
	
}

pub fn main() void {
	
	entry() catch |e| {
		@panic(@errorName(e));
	};
	
	if (efi.heap.amount != 0) {
		@panic("Memory leaks");
	}
	
	while (true) {
		asm volatile ("hlt");
	}
}