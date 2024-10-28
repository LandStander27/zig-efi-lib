const efi = @import("efi");
const std = @import("std");

pub const panic = efi.panic.panic_handler;
const log = efi.log;

fn digit_amount(n: u64) u64 {
	var amount: u64 = 0;
	var num = n;
	while (num > 0) : (num /= 10) {
		amount += 1;
	}
	return amount;
}

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
	
	const resolutions = try efi.graphics.get_resolutions(alloc);

	// Let user choose resolution.
	for (resolutions, 1..) |res, i| {
		try efi.io.print("{d}:", .{i});
		for (0..5-digit_amount(i)) |_| {
			try efi.io.print(" ", .{});
		}
		try efi.io.println("{d} x {d}", .{ res.width, res.height });
	}

	try efi.io.print("Resolution ? ", .{});

	var done = false;
	while (!done) {
		const res = try efi.io.getline(alloc);
		defer alloc.free(res);
		const n = std.fmt.parseInt(usize, res, 10) catch |e| {
			if (e == error.InvalidCharacter) {
				try efi.io.println("Not a number", .{});
				try efi.io.print("Resolution ? ", .{});
				continue;
			} else {
				return e;
			}
		};

		try efi.io.println("Set to {d} x {d}", .{ resolutions[n-1].width, resolutions[n-1].height });

		try efi.graphics.set_videomode(resolutions[n-1]);
		done = true;
	}

	alloc.free(resolutions);
	
	efi.graphics.clear();
	
	// Initialize the random module
	try efi.rng.init();
	
	// Disable the EFI Watchdog
	log.new_task("Watchdog");
	efi.bs.disable_watchdog() catch |e| {
		log.error_task_msg("{any}", .{e});
	};
	log.finish_task();

	try efi.fb.println("Starting snake...", .{});
	try efi.time.sleepms(1500);
	try @import("snake.zig").start(alloc);
	
	return Request.Shutdown;
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
		efi.panic.kernel_panic("On entry: {any}", .{e});
	};

	if (efi.heap.amount != 0) {
		const msg = if (efi.heap.amount > 1) "Detected memory leaks" else "Detected memory leak";
		efi.panic.kernel_panic_raw(msg);
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