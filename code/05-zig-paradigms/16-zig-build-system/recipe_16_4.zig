const std = @import("std");
const testing = std.testing;

// This file demonstrates custom build step concepts

// ANCHOR: step_info
// Information about a build step
pub const StepInfo = struct {
    name: []const u8,
    description: []const u8,
    is_default: bool,

    pub fn init(name: []const u8, description: []const u8, is_default: bool) StepInfo {
        return .{
            .name = name,
            .description = description,
            .is_default = is_default,
        };
    }

    pub fn isRunnable(self: StepInfo) bool {
        return self.name.len > 0;
    }
};

test "step info" {
    const step = StepInfo.init("codegen", "Generate code", false);
    try testing.expect(step.isRunnable());
    try testing.expect(!step.is_default);
    try testing.expect(std.mem.eql(u8, step.name, "codegen"));
}
// ANCHOR_END: step_info

// ANCHOR: command_step
// Represents an external command to run
pub const CommandStep = struct {
    program: []const u8,
    args: []const []const u8,
    working_dir: ?[]const u8,

    pub fn init(program: []const u8, args: []const []const u8) CommandStep {
        return .{
            .program = program,
            .args = args,
            .working_dir = null,
        };
    }

    pub fn withWorkingDir(self: CommandStep, dir: []const u8) CommandStep {
        var result = self;
        result.working_dir = dir;
        return result;
    }

    pub fn argCount(self: CommandStep) usize {
        return self.args.len;
    }
};

test "command step" {
    const args = [_][]const u8{ "--version" };
    const cmd = CommandStep.init("zig", &args);

    try testing.expectEqual(@as(usize, 1), cmd.argCount());
    try testing.expect(std.mem.eql(u8, cmd.program, "zig"));
    try testing.expect(cmd.working_dir == null);

    const cmd_with_dir = cmd.withWorkingDir("/tmp");
    try testing.expect(cmd_with_dir.working_dir != null);
}
// ANCHOR_END: command_step

// ANCHOR: file_generation
// File generation step
pub const FileGenerationStep = struct {
    source_file: []const u8,
    output_file: []const u8,
    generator: []const u8,

    pub fn init(source: []const u8, output: []const u8, generator: []const u8) FileGenerationStep {
        return .{
            .source_file = source,
            .output_file = output,
            .generator = generator,
        };
    }

    pub fn hasSource(self: FileGenerationStep) bool {
        return self.source_file.len > 0;
    }

    pub fn hasOutput(self: FileGenerationStep) bool {
        return self.output_file.len > 0;
    }

    pub fn isValid(self: FileGenerationStep) bool {
        return self.hasSource() and self.hasOutput() and self.generator.len > 0;
    }
};

test "file generation" {
    const gen = FileGenerationStep.init("schema.json", "generated.zig", "codegen");

    try testing.expect(gen.isValid());
    try testing.expect(gen.hasSource());
    try testing.expect(gen.hasOutput());
    try testing.expect(std.mem.eql(u8, gen.output_file, "generated.zig"));
}
// ANCHOR_END: file_generation

// ANCHOR: step_dependency
// Dependency between build steps
pub const StepDependency = struct {
    dependent: []const u8,
    dependency: []const u8,

    pub fn init(dependent: []const u8, dependency: []const u8) StepDependency {
        return .{
            .dependent = dependent,
            .dependency = dependency,
        };
    }

    pub fn dependsOn(self: StepDependency, step_name: []const u8) bool {
        return std.mem.eql(u8, self.dependency, step_name);
    }
};

test "step dependencies" {
    const dep = StepDependency.init("build", "codegen");

    try testing.expect(dep.dependsOn("codegen"));
    try testing.expect(!dep.dependsOn("test"));
    try testing.expect(std.mem.eql(u8, dep.dependent, "build"));
}
// ANCHOR_END: step_dependency

// ANCHOR: install_step
// Installation step configuration
pub const InstallStep = struct {
    artifact_name: []const u8,
    destination: []const u8,
    install_subdir: ?[]const u8,

    pub fn init(artifact: []const u8, destination: []const u8) InstallStep {
        return .{
            .artifact_name = artifact,
            .destination = destination,
            .install_subdir = null,
        };
    }

    pub fn withSubdir(self: InstallStep, subdir: []const u8) InstallStep {
        var result = self;
        result.install_subdir = subdir;
        return result;
    }

    pub fn hasSubdir(self: InstallStep) bool {
        return self.install_subdir != null;
    }
};

test "install step" {
    const install = InstallStep.init("myapp", "bin");

    try testing.expect(!install.hasSubdir());
    try testing.expect(std.mem.eql(u8, install.artifact_name, "myapp"));

    const with_sub = install.withSubdir("tools");
    try testing.expect(with_sub.hasSubdir());
}
// ANCHOR_END: install_step

// ANCHOR: run_step
// Run step configuration
pub const RunStep = struct {
    executable: []const u8,
    args: []const []const u8,
    description: []const u8,

    pub fn init(exe: []const u8, args: []const []const u8, desc: []const u8) RunStep {
        return .{
            .executable = exe,
            .args = args,
            .description = desc,
        };
    }

    pub fn hasArgs(self: RunStep) bool {
        return self.args.len > 0;
    }

    pub fn argCount(self: RunStep) usize {
        return self.args.len;
    }
};

test "run step" {
    const args = [_][]const u8{ "--help", "--version" };
    const run = RunStep.init("myapp", &args, "Run application");

    try testing.expect(run.hasArgs());
    try testing.expectEqual(@as(usize, 2), run.argCount());
    try testing.expect(std.mem.eql(u8, run.description, "Run application"));
}
// ANCHOR_END: run_step

// ANCHOR: check_step
// Check/lint step configuration
pub const CheckStep = struct {
    source_files: []const []const u8,
    checker: []const u8,
    fail_on_error: bool,

    pub fn init(files: []const []const u8, checker: []const u8) CheckStep {
        return .{
            .source_files = files,
            .checker = checker,
            .fail_on_error = true,
        };
    }

    pub fn allowErrors(self: CheckStep) CheckStep {
        var result = self;
        result.fail_on_error = false;
        return result;
    }

    pub fn fileCount(self: CheckStep) usize {
        return self.source_files.len;
    }
};

test "check step" {
    const files = [_][]const u8{ "main.zig", "lib.zig" };
    const check = CheckStep.init(&files, "zig fmt");

    try testing.expectEqual(@as(usize, 2), check.fileCount());
    try testing.expect(check.fail_on_error);

    const no_fail = check.allowErrors();
    try testing.expect(!no_fail.fail_on_error);
}
// ANCHOR_END: check_step

// ANCHOR: custom_target
// Custom build target
pub const CustomTarget = struct {
    name: []const u8,
    steps: []const []const u8,
    description: []const u8,

    pub fn init(name: []const u8, steps: []const []const u8, desc: []const u8) CustomTarget {
        return .{
            .name = name,
            .steps = steps,
            .description = desc,
        };
    }

    pub fn stepCount(self: CustomTarget) usize {
        return self.steps.len;
    }

    pub fn hasStep(self: CustomTarget, step_name: []const u8) bool {
        for (self.steps) |step| {
            if (std.mem.eql(u8, step, step_name)) return true;
        }
        return false;
    }
};

test "custom target" {
    const steps = [_][]const u8{ "codegen", "compile", "test" };
    const target = CustomTarget.init("full-build", &steps, "Complete build pipeline");

    try testing.expectEqual(@as(usize, 3), target.stepCount());
    try testing.expect(target.hasStep("codegen"));
    try testing.expect(!target.hasStep("deploy"));
}
// ANCHOR_END: custom_target

// ANCHOR: build_option
// Build option configuration
pub const BuildOption = struct {
    name: []const u8,
    option_type: []const u8,
    default_value: ?[]const u8,
    description: []const u8,

    pub fn init(name: []const u8, opt_type: []const u8, desc: []const u8) BuildOption {
        return .{
            .name = name,
            .option_type = opt_type,
            .default_value = null,
            .description = desc,
        };
    }

    pub fn withDefault(self: BuildOption, default: []const u8) BuildOption {
        var result = self;
        result.default_value = default;
        return result;
    }

    pub fn hasDefault(self: BuildOption) bool {
        return self.default_value != null;
    }
};

test "build option" {
    const opt = BuildOption.init("enable-logging", "bool", "Enable debug logging");

    try testing.expect(!opt.hasDefault());
    try testing.expect(std.mem.eql(u8, opt.name, "enable-logging"));

    const with_default = opt.withDefault("true");
    try testing.expect(with_default.hasDefault());
}
// ANCHOR_END: build_option
