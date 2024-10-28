const std = @import("std");
const uefi = std.os.uefi;
const heap = @import("heap.zig");

// std.ArrayList;

pub fn ArrayList(comptime T: type) type {
	return struct {

		const Self = @This();

		items: []T,
		data: []T,
		len: usize,
		capacity: usize,
		allocator: heap.Allocator,
		attached: bool = true,

		/// Allocates a managed slice.
		pub fn init(alloc: heap.Allocator) !Self {
			var data = try alloc.alloc(T, 16);
			return Self {
				.data = data,
				.items = data[0..0],
				.len = 0,
				.capacity = 16,
				.allocator = alloc
			};
		}

		/// Returns a copy of the contained slice and calls `self.deinit()`.
		pub fn detach(self: *Self) ![]T {
			const d: []T = try self.allocator.alloc(T, self.len);
			std.mem.copyForwards(T, d, self.items);
			self.deinit();
			return d;
		}

		/// Deallocates contained data.
		pub fn deinit(self: *Self) void {
			self.attached = false;
			self.allocator.free(self.data);
		}

		/// Remove element at `index`.
		pub fn remove(self: *Self, index: usize) void {
			for (index..self.len-1) |i| {
				self.data[i] = self.data[i+1];
			}
			self.items = self.data[0..self.len - 1];
			self.len -= 1;
		}

		fn grow(self: *Self) !void {
			if (self.len >= self.capacity) {
				self.data = try self.allocator.realloc(T, self.data, self.capacity * 2);
				self.capacity *= 2;
			}
		}

		/// Insert `T` at `index`, growing the slice when needed.
		pub fn insert(self: *Self, index: usize, item: T) !void {
			try self.grow();

			var i = self.len;
			while (i > index) : (i -= 1) {
				self.data[i] = self.data[i - 1];
			}
			self.data[index] = item;
			self.items = self.data[0..self.len + 1];
			self.len += 1;

		}

		/// Return pointer to last element, if any.
		pub fn last(self: *Self) ?*T {
			if (self.len == 0) {
				return null;
			}
			return &self.data[self.len - 1];
		}

		/// Insert `T` at `self.len`, growing the slice when needed.
		pub fn append(self: *Self, item: T) !void {
			try self.grow();
			self.data[self.len] = item;
			self.items = self.data[0..self.len + 1];
			self.len += 1;
		}

		/// Insert elements contained in `item` at `self.len`, growing the slice when needed.
		pub fn append_slice(self: *Self, item: []const T) !void {
			for (item) |i| {
				try self.append(i);
			}
		}

		/// Clear the contained slice.
		pub fn clear(self: *Self) void {
			self.len = 0;
			self.items = self.data[0..0];
		}

		/// Clear and reallocate the contained slice.
		pub fn reset(self: *Self) !void {
			self.data = try self.allocator.realloc(T, self.data, 16);
			self.capacity = 16;
			self.clear();
		}

	};
}
