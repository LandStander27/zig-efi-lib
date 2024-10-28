const efi = @import("efi");

const Color = efi.graphics.Color;

const square_size = 20;

const Type = enum {
	Snake,
	Food,
};

const Square = struct {
	x: i64,
	y: i64,
	typ: Type = .Snake,

	// Draw the square to the framebuffer
	pub fn draw(self: *const Square, buffer: *efi.graphics.Framebuffer) void {
		self.draw_color(buffer, Color{ .r = if (self.typ == .Food) 255 else 0, .g = if (self.typ == .Snake) 255 else 0, .b = 0 });
	}

	// Draw the square to the framebuffer with color
	pub fn draw_color(self: *const Square, buffer: *efi.graphics.Framebuffer, color: Color) void {
		if (self.x < 0 or self.y < 0) {
			return;
		}
		buffer.draw_rectangle(@intCast(self.x+1), @intCast(self.y+1), square_size-2, square_size-2, color);
	}
};

const Key = enum(u16) {
	Escape = 23,
	Down = 2,
	Up = 1,
	Left = 4,
	Right = 3,
};

const Direction = enum {
	Up,
	Down,
	Left,
	Right,
};

// Start the game
pub fn start(alloc: efi.heap.Allocator) !void {
	
	// Init the framebuffer
	var frame = try efi.graphics.Framebuffer.init(alloc);
	defer frame.deinit();
	const res = efi.graphics.current_resolution();
	
	// Init the food array
	var food = try efi.array.ArrayList(Square).init(alloc);
	defer food.deinit();
	
	const rows = res.height / square_size;
	const cols = res.width / square_size;

	try food.append(Square{ .x = @intCast((try efi.rng.random(0, cols))*square_size), .y = @intCast((try efi.rng.random(0, rows))*square_size), .typ = .Food });
	try food.append(Square{ .x = @intCast((try efi.rng.random(0, cols))*square_size), .y = @intCast((try efi.rng.random(0, rows))*square_size), .typ = .Food });
	
	// Init the snake array
	var snake = try efi.array.ArrayList(Square).init(alloc);
	defer snake.deinit();

	try snake.append(Square{ .x = 0, .y = 0 });

	for (0..3) |_| {
		try snake.append(Square{ .x = snake.last().?.x + square_size, .y = 0 });
	}
	
	var current_direction = Direction.Right;

	var dead = false;
	var running = true;
	
	while (running) {
		const key = try efi.io.getkey();
		if (key) |k| {
			if (@intFromEnum(Key.Escape) == k.scancode) {
				running = false;
			}
			
			if (!dead) {
				switch (k.scancode) {
					@intFromEnum(Key.Down) => current_direction = if (current_direction != Direction.Up) Direction.Down else current_direction,
					@intFromEnum(Key.Up) => current_direction = if (current_direction != Direction.Down) Direction.Up else current_direction,
					@intFromEnum(Key.Left) => current_direction = if (current_direction != Direction.Right) Direction.Left else current_direction,
					@intFromEnum(Key.Right) => current_direction = if (current_direction != Direction.Left) Direction.Right else current_direction,
					else => {},
				}
			} else if (k.unicode.convert() == ' ') {
				dead = false;
				food.clear();
				try snake.reset();

				try food.append(Square{ .x = @intCast((try efi.rng.random(0, cols))*square_size), .y = @intCast((try efi.rng.random(0, rows))*square_size), .typ = .Food });
				try food.append(Square{ .x = @intCast((try efi.rng.random(0, cols))*square_size), .y = @intCast((try efi.rng.random(0, rows))*square_size), .typ = .Food });
				
				try snake.append(Square{ .x = 0, .y = 0 });
				for (0..3) |_| {
					try snake.append(Square{ .x = snake.last().?.x + square_size, .y = 0 });
				}
				
				current_direction = Direction.Right;
			}
		}
		
		if (!dead) {
			snake.remove(0);
			var new_square = Square{ .x = snake.last().?.x, .y = snake.last().?.y };
			switch (current_direction) {
				Direction.Up => new_square.y -= square_size,
				Direction.Down => new_square.y += square_size,
				Direction.Left => new_square.x -= square_size,
				Direction.Right => new_square.x += square_size,
			}
			try snake.append(new_square);
			for (food.items, 0..) |apple, i| {
				if (snake.last().?.x == apple.x and snake.last().?.y == apple.y) {
					food.remove(i);
					try food.append(Square{ .x = @intCast((try efi.rng.random(0, cols))*square_size), .y = @intCast((try efi.rng.random(0, rows))*square_size), .typ = .Food });
					try snake.insert(0, Square{ .x = snake.items[0].x, .y = snake.items[0].y });
					break;
				}
			}
			for (snake.items[0..snake.items.len - 2]) |*s| {
				if (snake.last().?.x == s.x and snake.last().?.y == s.y) {
					dead = true;
					break;
				}
			}
			if (snake.last().?.x < 0 or snake.last().?.x >= res.width or snake.last().?.y < 0 or snake.last().?.y >= res.height) {
				dead = true;
			}
		}
		
		frame.clear();
		for (snake.items) |i| {
			i.draw(&frame);
		}
		for (food.items) |i| {
			i.draw(&frame);
		}
		
		if (dead) {
			snake.last().?.draw_color(&frame, Color{ .r = 255, .g = 165, .b = 0 });
			frame.draw_text_centered("Oh no! You died!", res.width/2, res.height/2, null, null);
			frame.draw_text_centered("Press space to restart", res.width/2, res.height/2+efi.fb.font_height, null, null);
			frame.draw_text_centered("Press escape to exit", res.width/2, res.height/2+efi.fb.font_height*2, null, null);
		}
		
		try frame.update();
		try efi.time.sleepms(100);
	}
}
