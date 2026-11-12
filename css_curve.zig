//! Curves as CSS timing functions: a bezier as `cubic-bezier()`, a spring sampled into
//! `linear()`, which CSS draws as straight lines between the samples.

const std = @import("std");
const kosm = @import("kosm");

/// Samples a spring is drawn with; enough that the corners between them don't show.
const spring_samples = 100;

/// `curve` as a CSS timing function for an animation lasting `duration` seconds; a spring is cut
/// off where the duration ends, wherever it is then. The text lives in `allocator`.
pub fn timingFunction(allocator: std.mem.Allocator, curve: kosm.Curve, duration: f64) std.mem.Allocator.Error![]const u8 {
    switch (curve) {
        .bezier => |bezier| return allocator.print("cubic-bezier({d}, {d}, {d}, {d})", .{ bezier.x1, bezier.y1, bezier.x2, bezier.y2 }),
        .spring => |spring| {
            var text: std.Io.Writer.Allocating = .init(allocator);
            errdefer text.deinit();
            const writer = &text.writer;
            writer.writeAll("linear(") catch return error.OutOfMemory;
            for (0..spring_samples + 1) |sample| {
                const time = duration * @as(f64, @floatFromInt(sample)) / spring_samples;
                const separator = if (sample == 0) "" else ", ";
                writer.print("{s}{d:.6} {d}%", .{ separator, springPosition(spring, time), sample * 100 / spring_samples }) catch return error.OutOfMemory;
            }
            writer.writeAll(")") catch return error.OutOfMemory;
            return text.toOwnedSlice();
        },
    }
}

/// How far a spring released from rest at 0 has moved toward its rest at 1 after `time` seconds.
fn springPosition(spring: kosm.Curve.Spring, time: f64) f64 {
    const natural = @sqrt(spring.stiffness / spring.mass);
    const ratio = spring.damping / (2 * @sqrt(spring.stiffness * spring.mass));
    if (ratio < 1) {
        const damped = natural * @sqrt(1 - ratio * ratio);
        return 1 - @exp(-ratio * natural * time) * (@cos(damped * time) + ratio * natural / damped * @sin(damped * time));
    }
    if (ratio == 1) return 1 - @exp(-natural * time) * (1 + natural * time);
    const spread = natural * @sqrt(ratio * ratio - 1);
    const slow = -ratio * natural + spread;
    const fast = -ratio * natural - spread;
    return 1 + (fast * @exp(slow * time) - slow * @exp(fast * time)) / (slow - fast);
}

const testing = std.testing;

test "a bezier is CSS's cubic-bezier" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    try testing.expectEqualStrings("cubic-bezier(0.175, 0.885, 0.32, 1.35)", try timingFunction(arena.allocator(), .cubicBezier(0.175, 0.885, 0.32, 1.35), 0.25));
}

test "an underdamped spring overshoots once and settles, as Zen's sidebar spring does" {
    const spring: kosm.Curve.Spring = .{ .stiffness = 914.5, .damping = 49.6 };
    try testing.expectApproxEqAbs(0.497, springPosition(spring, 0.2 * 0.25), 0.001);
    try testing.expectApproxEqAbs(1.0109, springPosition(spring, 0.73 * 0.25), 0.001);
    try testing.expectApproxEqAbs(1, springPosition(spring, 10), 1e-9);
}

test "a spring is sampled from rest at 0 into linear(), and over- and critically damped ones never overshoot" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const text = try timingFunction(arena.allocator(), .{ .spring = .{ .stiffness = 914.5, .damping = 49.6 } }, 0.25);
    try testing.expect(std.mem.startsWith(u8, text, "linear(0.000000 0%, 0.002"));
    try testing.expect(std.mem.endsWith(u8, text, " 100%)"));
    try testing.expectEqual(spring_samples + 1, std.mem.count(u8, text, "%"));

    // Stiffness 100 with mass 1 is critically damped at 20.
    for ([_]f64{ 20, 200 }) |damping| {
        const spring: kosm.Curve.Spring = .{ .stiffness = 100, .damping = damping };
        var previous: f64 = 0;
        for (1..200) |step| {
            const position = springPosition(spring, @as(f64, @floatFromInt(step)) / 50);
            try testing.expect(position >= previous and position <= 1);
            previous = position;
        }
    }
}
