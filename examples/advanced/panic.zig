const efi = @import("efi");

pub fn kernel_panic(comptime format: []const u8, args: anytype) noreturn {
	const ArgsType = @TypeOf(args);
	const args_type_info = @typeInfo(ArgsType);
	const fields_info = args_type_info.Struct.fields;
	const alloc = efi.heap.Allocator.init();
	const msg = blk: {
		if (fields_info.len == 0) {
			break :blk format;
		} else {
			break :blk efi.io.alloc_print(alloc, format, args) catch {
				break :blk format;
			};
		}
	};
	defer {
		if (msg.ptr != format.ptr) alloc.free(msg);
	}

	kernel_panic_raw(msg);
}

pub fn kernel_panic_raw(msg: []const u8) noreturn {

	const on_heap = efi.heap.amount;
	const alloc = efi.heap.Allocator.init();
	if (efi.graphics.has_inited()) {
		(blk: {
			if (efi.fb.font_loaded) {
				efi.fb.free_font(alloc);
			}
			efi.fb.load_builtin_font(alloc) catch |e| {
				break :blk e;
			};
			var framebuffer = efi.graphics.Framebuffer.init(alloc) catch |e| {
				break :blk e;
			};
			defer framebuffer.deinit();

			framebuffer.clear_color(efi.graphics.Color{ .r = 0, .g = 0, .b = 255 });
			const res = efi.graphics.current_resolution();
			const y_offset: u32 = if (on_heap > 0) 32 else 16;
			framebuffer.draw_text_centered("KERNEL PANIC !", res.width/2, res.height/2-y_offset, efi.fb.White, efi.fb.Blue);

			if (on_heap > 0) {
				framebuffer.draw_text_centeredf("OBJECTS ON HEAP FROM BEFORE PANIC: {d}", .{on_heap}, res.width/2, res.height/2-16, efi.fb.White, efi.fb.Blue) catch |e| {
					break :blk e;
				};
			}

			framebuffer.draw_text_centered(msg, res.width/2, res.height/2+16, efi.fb.White, efi.fb.Blue);
			var input_works = true;
			_ = efi.io.getkey() catch {
				input_works = false;
			};

			if (input_works) {
				framebuffer.draw_text_centered("Press `Esc` to load framebuffer state from before panic (debugging)\nPress `Enter` to attempt a software reboot (recommended)\nPress `Space` to attempt a hardware reboot\nPress `^C` to attempt a shutdown", res.width/2, res.height-80, efi.fb.White, efi.fb.Blue);
				var state = efi.graphics.State.init(alloc) catch |e| {
					break :blk e;
				};
				defer {
					if (state.inited) state.deinit();
				}
				var framebuffer_before = efi.graphics.Framebuffer.init(alloc) catch |e| {
					break :blk e;
				};
				defer framebuffer_before.deinit();

				framebuffer_before.load_state(state);
				state.deinit();
				framebuffer_before.draw_text_centered("Press `Esc` to go back to panic screen\nPress `Enter` to attempt a software reboot (recommended)\nPress `Space` to attempt a hardware reboot\nPress `^C` to attempt a shutdown", res.width/2, res.height-80, efi.fb.White, efi.fb.Blue);
				framebuffer.update() catch |e| {
					break :blk e;
				};

				var panic_state = efi.graphics.State.init(alloc) catch |e| {
					break :blk e;
				};
				defer panic_state.deinit();
				var before_loaded = false;
				while (true) {
					const key = efi.io.getkey() catch |e| {
						break :blk e;
					};

					if (key == null) continue;

					if (key.?.unicode.convert() == ' ') {
						framebuffer.draw_text_centered("Attempting to hardware reboot", res.width/2, 16, efi.fb.White, efi.fb.Blue);
						framebuffer.update() catch |e| {
							break :blk e;
						};
						efi.time.sleepms(750) catch {};
						efi.bs.hardware_reboot();
					} else if (key.?.unicode.char == 13) {
						framebuffer.draw_text_centered("Attempting to software reboot", res.width/2, 16, efi.fb.White, efi.fb.Blue);
						framebuffer.update() catch |e| {
							break :blk e;
						};
						efi.time.sleepms(750) catch {};
						efi.bs.software_reboot();
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
						framebuffer.draw_text_centered("Attempting to shutdown", res.width/2, 16, efi.fb.White, efi.fb.Blue);
						framebuffer.update() catch |e| {
							break :blk e;
						};
						efi.time.sleepms(750) catch {};
						efi.bs.shutdown();
					}
				}
			} else {
				framebuffer.update() catch |e| {
					break :blk e;
				};
			}
		} catch {
			efi.fb.set_color(efi.fb.Red);
			efi.fb.puts("KERNEL PANIC: ");
			efi.fb.puts(msg);
			efi.fb.puts("\n");
			efi.fb.puts("OBJECTS ON HEAP: ");
			efi.fb.print("{d}\n", .{efi.heap.amount}) catch {
				efi.io.println("{d}", .{efi.heap.amount}) catch {
					efi.io.puts("COULD NOT PRINT OBJECTS ON HEAP\n");
				};
			};
			efi.fb.set_color(efi.fb.White);
		});
	} else {
		efi.io.puts("KERNEL PANIC: ");
		efi.io.puts(msg);
		efi.io.puts("\n");
		efi.io.puts("OBJECTS ON HEAP: ");
		efi.io.print("{d}\n", .{efi.heap.amount}) catch {
			efi.io.puts("COULD NOT PRINT OBJECTS ON HEAP\n");
		};
	}
	while (true) {
		asm volatile ("hlt");
	}
}