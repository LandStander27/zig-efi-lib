const efi = @import("efi");

pub fn main() void {
	efi.io.init_io() catch |e| {
		@panic(@errorName(e));
	};
	
	efi.io.print("Hello, World!\n", .{}) catch |e| {
		@panic(@errorName(e));
	};
	
	while (true) {
		asm volatile ("hlt");
	}
}