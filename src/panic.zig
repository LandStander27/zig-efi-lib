const heap = @import("heap.zig");
const fb = @import("fb.zig");
const io = @import("io.zig");
const graphics = @import("graphics.zig");
const time = @import("time.zig");
const bs = @import("boot_services.zig");

/// Wrapper around `panic.kernel_panic_raw`.
pub fn panic_handler(msg: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
	kernel_panic_raw(msg);
}

/// Panic with a formatted string.
/// Wrapper around `panic.kernel_panic_raw`.
pub fn kernel_panic(comptime format: []const u8, args: anytype) noreturn {
	const ArgsType = @TypeOf(args);
	const args_type_info = @typeInfo(ArgsType);
	const fields_info = args_type_info.Struct.fields;
	const alloc = heap.Allocator.init();
	const msg = blk: {
		if (fields_info.len == 0) {
			break :blk format;
		} else {
			break :blk io.alloc_print(alloc, format, args) catch {
				break :blk format;
			};
		}
	};
	defer {
		if (msg.ptr != format.ptr) alloc.free(msg);
	}

	kernel_panic_raw(msg);
}

/// Panic handler.
/// Fallbacks go from: GUI with available debugging options, printing info to framebuffer, to printing info to EFI con_out.
pub fn kernel_panic_raw(msg: []const u8) noreturn {

	const on_heap = heap.amount;
	const alloc = heap.Allocator.init();
	if (graphics.has_inited()) {
		(blk: {
			if (fb.font_loaded) {
				fb.free_font(alloc);
			}
			fb.load_builtin_font(alloc) catch |e| {
				break :blk e;
			};
			var framebuffer = graphics.Framebuffer.init(alloc) catch |e| {
				break :blk e;
			};
			defer framebuffer.deinit();

			framebuffer.clear_color(graphics.Color{ .r = 0, .g = 0, .b = 255 });
			const res = graphics.current_resolution();
			const y_offset: u32 = if (on_heap > 0) 32 else 16;
			framebuffer.draw_text_centered("KERNEL PANIC !", res.width/2, res.height/2-y_offset, fb.White, fb.Blue);

			if (on_heap > 0) {
				framebuffer.draw_text_centeredf("OBJECTS ON HEAP FROM BEFORE PANIC: {d}", .{on_heap}, res.width/2, res.height/2-16, fb.White, fb.Blue) catch |e| {
					break :blk e;
				};
			}

			framebuffer.draw_text_centered(msg, res.width/2, res.height/2+16, fb.White, fb.Blue);
			var input_works = true;
			_ = io.getkey() catch {
				input_works = false;
			};

			if (input_works) {
				framebuffer.draw_text_centered("Press `Esc` to load framebuffer state from before panic (debugging)\nPress `Enter` to attempt a software reboot (recommended)\nPress `Space` to attempt a hardware reboot\nPress `^C` to attempt a shutdown", res.width/2, res.height-80, fb.White, fb.Blue);
				var state = graphics.State.init(alloc) catch |e| {
					break :blk e;
				};
				defer {
					if (state.inited) state.deinit();
				}
				var framebuffer_before = graphics.Framebuffer.init(alloc) catch |e| {
					break :blk e;
				};
				defer framebuffer_before.deinit();

				framebuffer_before.load_state(state);
				state.deinit();
				framebuffer_before.draw_text_centered("Press `Esc` to go back to panic screen\nPress `Enter` to attempt a software reboot (recommended)\nPress `Space` to attempt a hardware reboot\nPress `^C` to attempt a shutdown", res.width/2, res.height-80, fb.White, fb.Blue);
				framebuffer.update() catch |e| {
					break :blk e;
				};

				var panic_state = graphics.State.init(alloc) catch |e| {
					break :blk e;
				};
				defer panic_state.deinit();
				var before_loaded = false;
				while (true) {
					const key = io.getkey() catch |e| {
						break :blk e;
					};

					if (key == null) continue;

					if (key.?.unicode.convert() == ' ') {
						framebuffer.draw_text_centered("Attempting to hardware reboot", res.width/2, 16, fb.White, fb.Blue);
						framebuffer.update() catch |e| {
							break :blk e;
						};
						time.sleepms(750) catch {};
						bs.hardware_reboot();
					} else if (key.?.unicode.char == 13) {
						framebuffer.draw_text_centered("Attempting to software reboot", res.width/2, 16, fb.White, fb.Blue);
						framebuffer.update() catch |e| {
							break :blk e;
						};
						time.sleepms(750) catch {};
						bs.software_reboot();
					} else if (key.?.scancode == 23) {
						if (!before_loaded) {
							framebuffer_before.update() catch |e| {
								break :blk e;
							};
						} else {
							framebuffer.update() catch |e| {
								break :blk e;
							};
						}
						before_loaded = !before_loaded;
					} else if (key.?.ctrl and key.?.unicode.convert() == 'c') {
						framebuffer.draw_text_centered("Attempting to shutdown", res.width/2, 16, fb.White, fb.Blue);
						framebuffer.update() catch |e| {
							break :blk e;
						};
						time.sleepms(750) catch {};
						bs.shutdown();
					}
				}
			} else {
				framebuffer.update() catch |e| {
					break :blk e;
				};
			}
		} catch {
			fb.set_color(fb.Red);
			fb.puts("KERNEL PANIC: ");
			fb.puts(msg);
			fb.puts("\n");
			fb.puts("OBJECTS ON HEAP: ");
			fb.print("{d}\n", .{heap.amount}) catch {
				io.println("{d}", .{heap.amount}) catch {
					io.puts("COULD NOT PRINT OBJECTS ON HEAP\n");
				};
			};
			fb.set_color(fb.White);
		});
	} else {
		io.puts("KERNEL PANIC: ");
		io.puts(msg);
		io.puts("\n");
		io.puts("OBJECTS ON HEAP: ");
		io.print("{d}\n", .{heap.amount}) catch {
			io.puts("COULD NOT PRINT OBJECTS ON HEAP\n");
		};
	}
	while (true) {
		asm volatile ("hlt");
	}
}