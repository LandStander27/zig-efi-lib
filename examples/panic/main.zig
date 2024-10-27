const efi = @import("efi");

// Sets the global panic handler
pub const panic = efi.panic.panic_handler;

fn entry() !void {
	
	const alloc = efi.heap.Allocator.init();
	
	// Load the embedded font into memory
	try efi.fb.load_builtin_font(alloc);
	defer efi.fb.free_font(alloc);
	
	// Initialize graphics buffer
	try efi.graphics.init();
	efi.graphics.clear();
	
	try efi.fb.println("Panicking in 3 seconds...", .{});
	try efi.time.sleepms(3000);
	
	@panic("Panic message");
	// @panic == efi.panic.kernel_panic_raw
	// Optionally, efi.panic.kernel_panic provides formatting, with a fallback to using the format string as the panic message
	
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
