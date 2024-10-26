const std = @import("std");
const Target = std.Target;
const CrossTarget = std.Target.Query;

pub fn build(b: *std.Build) !void {
	// const target = b.standardTargetOptions(.{});
	const target = CrossTarget{ .cpu_arch = .x86_64, .os_tag = .uefi, .abi = .msvc };

	const optimize = b.standardOptimizeOption(.{});

	const module = b.addModule("efi", .{
		.root_source_file = b.path("src/main.zig"),
		.target = b.resolveTargetQuery(target),
		.optimize = optimize,
	});
	
	inline for ([_]struct {
		name: []const u8,
		src: []const u8,
	} {
		.{ .name = "hello", .src = "examples/hello/main.zig" },
	}) |excfg| {
		const ex_name = excfg.name;
		const ex_src = excfg.src;
		
		const ex_build_desc = try std.fmt.allocPrint(b.allocator, "build the {s} example", .{ex_name});
		const ex_run_stepname = try std.fmt.allocPrint( b.allocator, "run-{s}", .{ex_name});
		const ex_run_stepdesc = try std.fmt.allocPrint( b.allocator, "run the {s} example", .{ex_name});
		
		const example_run_step = b.step(ex_run_stepname, ex_run_stepdesc);
		const example_step = b.step(ex_name, ex_build_desc);
		
		var example = b.addExecutable(.{
			.name = "bootx64",
			.root_source_file = b.path(ex_src),
			.target = b.resolveTargetQuery(target),
			.optimize = optimize,
		});
		
		example.root_module.addImport("efi", module);
		
		const example_run = b.addRunArtifact(example);
		example_run_step.dependOn(&example_run.step);
		
		const example_build_step = b.addInstallArtifact(example, .{
			.dest_dir = .{
				.override = .{
					.custom = "../bin/EFI/BOOT",
				},
			},
		});
		example_step.dependOn(&example_build_step.step);
		
	}
}
