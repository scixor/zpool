const std = @import("std");

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

pub fn asTypeId(comptime typeInfo: std.builtin.Type) std.builtin.TypeId {
    return @as(std.builtin.TypeId, typeInfo);
}

pub fn typeIdOf(comptime T: type) std.builtin.TypeId {
    return asTypeId(@typeInfo(T));
}

pub fn isStruct(comptime T: type) bool {
    return typeIdOf(T) == std.builtin.TypeId.@"struct";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

/// A comptime field descriptor mirroring the old `std.meta.fields` element
/// type, rebuilt from the new `@typeInfo(...).@"struct"` API.
pub const FieldInfo = struct {
    name: []const u8,
    type: type,
    is_comptime: bool,
    alignment: ?usize,
    default_value_ptr: ?*const anyopaque,
};

/// Equivalent of the removed `std.meta.fields(T)` for structs, returning a
/// comptime slice of `FieldInfo`.
pub fn fields(comptime T: type) []const FieldInfo {
    return comptime blk: {
        const info = @typeInfo(T).@"struct";
        var result: [info.field_names.len]FieldInfo = undefined;
        for (
            info.field_names,
            info.field_types,
            info.field_attrs,
            &result,
        ) |name, field_type, attrs, *f| {
            f.* = .{
                .name = name,
                .type = field_type,
                .is_comptime = attrs.@"comptime",
                .alignment = attrs.@"align",
                .default_value_ptr = attrs.default_value_ptr,
            };
        }
        const final = result;
        break :blk &final;
    };
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

/// UInt(bits) returns an unsigned integer type of the requested bit width.
pub fn UInt(comptime bits: u8) type {
    return @Int(.unsigned, bits);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

/// Returns an unsigned integer type with ***at least*** `min_bits`,
/// that is also large enough to be addressable by a normal pointer.
/// The returned type will always be one of the following:
/// * `u8`
/// * `u16`
/// * `u32`
/// * `u64`
/// * `u128`
/// * `u256`
pub fn AddressableUInt(comptime min_bits: u8) type {
    return switch (min_bits) {
        0...8 => u8,
        9...16 => u16,
        17...32 => u32,
        33...64 => u64,
        65...128 => u128,
        129...255 => u256,
    };
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

/// Given: `Struct = struct { foo: u32, bar: u64 }`
/// Returns: `StructOfSlices = struct { foo: []u32, bar: []u64 }`
pub fn StructOfSlices(comptime Struct: type) type {
    const info = @typeInfo(Struct).@"struct";
    var field_names: [info.field_names.len][]const u8 = undefined;
    var field_types: [info.field_types.len]type = undefined;

    inline for (
        info.field_names,
        info.field_types,
        info.field_attrs,
        &field_names,
        &field_types,
    ) |name, element_type, attrs, *new_name, *NewType| {
        // u32 -> []u32
        const FieldType = @Pointer(
            .slice,
            .{ .@"align" = attrs.@"align" },
            element_type,
            null,
        );

        new_name.* = name;
        NewType.* = FieldType;
    }

    return @Struct(
        .auto,
        null,
        &field_names,
        &field_types,
        &@splat(.{}),
    );
}

test "StructOfSlices" {
    const expectEqual = std.testing.expectEqual;

    const Struct = struct { a: u16, b: u16, c: u16 };
    try expectEqual(@sizeOf(u16) * 3, @sizeOf(Struct));

    const SOS = StructOfSlices(Struct);
    try expectEqual(@sizeOf([]u16) * 3, @sizeOf(SOS));
}
