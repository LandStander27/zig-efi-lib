const efi = @import("efi");

fn entry() !void {
	
	const alloc = efi.heap.Allocator.init();
	
	// Load the embedded font into memory
	try efi.fb.load_builtin_font(alloc);
	defer efi.fb.free_font(alloc);
	
	// Initialize graphics buffer
	try efi.graphics.init();
	
	try efi.rng.init();
	
	efi.graphics.clear();
	const msg = "Hello from Zig OS!";
	for (msg) |c| {
		try efi.fb.print("{c}", .{c});
		try efi.time.sleepms(try efi.rng.random(75, 150));
	}
	
	try efi.fb.print("\n", .{});
	
	// Draw a red rectangle in the middle of the screen
	const res = efi.graphics.current_resolution();
	efi.graphics.draw_rectangle(res.width/2-25, res.height/2-25, 50, 50, efi.graphics.Color{ .r = 255, .g = 0, .b = 0 });
	
}

pub fn main() void {
	
	efi.io.init_io() catch |e| {
		@panic(@errorName(e));
	};
	
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
