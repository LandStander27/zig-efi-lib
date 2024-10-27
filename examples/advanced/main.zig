const efi = @import("efi");

pub const panic = efi.panic.panic_handler;
const log = efi.log;

fn entry() !Request {
	
	// Initialize boot services (technically not required)
	log.new_task("BootServices");
	_ = efi.bs.init() catch {
		@panic("Could not start boot services");
	};
	log.finish_task();
	
	const alloc = efi.heap.Allocator.init();
	
	// Make sure the heap works
	log.new_task("InitHeap");
	for (0..100) |_| {
		const a = alloc.alloc(u8, 1) catch |e| {
			log.error_task();
			@panic(@errorName(e));
		};
		alloc.free(a);
		try efi.time.sleepms(10);
	}
	log.finish_task();

	// Load embedded font into memory
	try efi.fb.load_builtin_font(alloc);
	defer efi.fb.free_font(alloc);

	// Initialize graphics buffer
	try efi.graphics.init();
	efi.graphics.clear();
	
	// Initialize the filesystem
	try efi.fs.init(alloc);
	defer efi.fs.deinit();

	// Mount the root filesystem
	try efi.fs.mount_root();
	defer {
		efi.fs.umount_root() catch |e| {
			efi.panic.kernel_panic("On root umount: {any}", .{e});
		};
	}
	
	// Initialize the random module
	try efi.rng.init();
	
	// Disable the EFI Watchdog
	log.new_task("Watchdog");
	efi.bs.disable_watchdog() catch |e| {
		log.error_task_msg("{any}", .{e});
	};
	log.finish_task();

	try efi.fb.println("Done.", .{});
	
	return .Exit;
	
}

const Request = enum {
	SoftwareReboot,
	Reboot,
	Shutdown,
	Exit,
};

pub fn main() void {
	efi.io.init_io() catch |e| {
		@panic(@errorName(e));
	};

	efi.io.puts("Reached target entry\n");
	const req = entry() catch |e| {
		panic.kernel_panic("On entry: {any}", .{e});
	};

	if (efi.heap.amount != 0) {
		const msg = if (efi.heap.amount > 1) "Detected memory leaks" else "Detected memory leak";
		panic.kernel_panic_raw(msg);
	}

	switch (req) {
		Request.Exit => {},
		Request.Shutdown => {
			efi.io.puts("Reached target shutdown");
			efi.time.sleepms(1000) catch {};
			efi.bs.exit_services() catch {
				efi.io.puts("EXIT SERVICES FAILED");
				efi.time.sleepms(5000) catch {};
			};
			efi.bs.shutdown();
		},
		Request.Reboot => {
			efi.io.puts("Reached target reboot");
			efi.time.sleepms(1000) catch {};
			efi.bs.exit_services() catch {
				efi.io.puts("EXIT SERVICES FAILED");
				efi.time.sleepms(5000) catch {};
			};
			efi.bs.hardware_reboot();
		},
		else => {}
	}

	while (true) {
		asm volatile ("hlt");
	}

}