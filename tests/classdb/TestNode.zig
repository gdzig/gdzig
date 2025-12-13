const TestNode = @This();

base: *Node,
counter: i64 = 0,
my_property: i64 = 42,
indexed_values: [3]i64 = .{ 100, 200, 300 },

pub fn create() !*TestNode {
    const self: *TestNode = testing.allocator.create(TestNode) catch @panic("out of memory");
    self.* = .{ .base = Node.init() };
    self.base.setInstance(TestNode, self);
    return self;
}

pub fn destroy(self: *TestNode) void {
    testing.allocator.destroy(self);
}

pub fn increment(self: *TestNode) void {
    self.counter += 1;
}

pub fn getCounter(self: *TestNode) i64 {
    return self.counter;
}

pub fn addValue(self: *TestNode, value: i64) i64 {
    self.counter += value;
    return self.counter;
}

pub fn getMyProperty(self: *TestNode) i64 {
    return self.my_property;
}

pub fn setMyProperty(self: *TestNode, value: i64) void {
    self.my_property = value;
}

pub fn getIndexedValue(self: *TestNode, index: i64) i64 {
    if (index >= 0 and index < 3) {
        return self.indexed_values[@intCast(index)];
    }
    return 0;
}

pub fn setIndexedValue(self: *TestNode, index: i64, value: i64) void {
    if (index >= 0 and index < 3) {
        self.indexed_values[@intCast(index)] = value;
    }
}

pub fn register() void {
    var class_name = StringName.fromComptimeLatin1("TestNode");
    var base_class_name = StringName.fromComptimeLatin1("Node");

    ClassDB.registerClass3(TestNode, void, void, &class_name, &base_class_name, .{}, .{
        .create = create,
        .destroy = destroy,
    });

    var int_return = ClassDB.PropertyInfo{ .type = .int };

    // Method: increment()
    var increment_name = StringName.fromComptimeLatin1("increment");
    ClassDB.registerMethod(TestNode, void, &class_name, .{
        .name = &increment_name,
    }, .{
        .call = callIncrement,
    });

    // Method: get_counter() -> int
    var get_counter_name = StringName.fromComptimeLatin1("get_counter");
    ClassDB.registerMethod(TestNode, void, &class_name, .{
        .name = &get_counter_name,
        .return_value_info = &int_return,
    }, .{
        .call = callGetCounter,
    });

    // Method: add_value(value: int) -> int
    var add_value_name = StringName.fromComptimeLatin1("add_value");
    var value_arg_name = StringName.fromComptimeLatin1("value");
    var value_arg = [_]ClassDB.PropertyInfo{.{ .type = .int, .name = &value_arg_name }};
    var one_arg_meta = [_]ClassDB.MethodArgumentMetadata{.none};
    ClassDB.registerMethod(TestNode, void, &class_name, .{
        .name = &add_value_name,
        .return_value_info = &int_return,
        .argument_info = &value_arg,
        .argument_metadata = &one_arg_meta,
    }, .{
        .call = callAddValue,
    });

    // Signal: counter_changed(new_value: int)
    var signal_name = StringName.fromComptimeLatin1("counter_changed");
    var new_value_name = StringName.fromComptimeLatin1("new_value");
    var signal_args = [_]ClassDB.PropertyInfo{.{ .type = .int, .name = &new_value_name }};
    ClassDB.registerSignal(&class_name, &signal_name, &signal_args);

    // Property: my_property
    var get_my_property_name = StringName.fromComptimeLatin1("get_my_property");
    var set_my_property_name = StringName.fromComptimeLatin1("set_my_property");

    ClassDB.registerMethod(TestNode, void, &class_name, .{
        .name = &get_my_property_name,
        .return_value_info = &int_return,
    }, .{ .call = callGetMyProperty });

    ClassDB.registerMethod(TestNode, void, &class_name, .{
        .name = &set_my_property_name,
        .argument_info = &value_arg,
        .argument_metadata = &one_arg_meta,
    }, .{ .call = callSetMyProperty });

    var my_property_name = StringName.fromComptimeLatin1("my_property");
    var property_info = ClassDB.PropertyInfo{ .type = .int, .name = &my_property_name };
    ClassDB.registerProperty(&class_name, &property_info, &set_my_property_name, &get_my_property_name);

    // Indexed property: indexed_value[index]
    var get_indexed_name = StringName.fromComptimeLatin1("get_indexed_value");
    var set_indexed_name = StringName.fromComptimeLatin1("set_indexed_value");
    var index_arg_name = StringName.fromComptimeLatin1("index");
    var index_arg = [_]ClassDB.PropertyInfo{.{ .type = .int, .name = &index_arg_name }};
    var two_args = [_]ClassDB.PropertyInfo{
        .{ .type = .int, .name = &index_arg_name },
        .{ .type = .int, .name = &value_arg_name },
    };
    var two_arg_meta = [_]ClassDB.MethodArgumentMetadata{ .none, .none };

    ClassDB.registerMethod(TestNode, void, &class_name, .{
        .name = &get_indexed_name,
        .return_value_info = &int_return,
        .argument_info = &index_arg,
        .argument_metadata = &one_arg_meta,
    }, .{ .call = callGetIndexedValue });

    ClassDB.registerMethod(TestNode, void, &class_name, .{
        .name = &set_indexed_name,
        .argument_info = &two_args,
        .argument_metadata = &two_arg_meta,
    }, .{ .call = callSetIndexedValue });

    var indexed_property_name = StringName.fromComptimeLatin1("indexed_value");
    var indexed_property_info = ClassDB.PropertyInfo{ .type = .int, .name = &indexed_property_name };
    ClassDB.registerPropertyIndexed(&class_name, &indexed_property_info, &set_indexed_name, &get_indexed_name, 0);

    // Property groups
    var group_name = String.fromLatin1("Test Group");
    var group_prefix = String.fromLatin1("test_");
    ClassDB.registerPropertyGroup(&class_name, &group_name, &group_prefix);

    var subgroup_name = String.fromLatin1("Test Subgroup");
    var subgroup_prefix = String.fromLatin1("test_sub_");
    ClassDB.registerPropertySubgroup(&class_name, &subgroup_name, &subgroup_prefix);

    // Integer constants
    var enum_name = StringName.fromComptimeLatin1("MyEnum");
    var constant_name = StringName.fromComptimeLatin1("MY_CONSTANT");
    ClassDB.registerIntegerConstant(&class_name, &enum_name, &constant_name, 123, false);

    // Bitfield flags
    var bitfield_name = StringName.fromComptimeLatin1("MyFlags");
    var flag_name = StringName.fromComptimeLatin1("FLAG_ONE");
    ClassDB.registerIntegerConstant(&class_name, &bitfield_name, &flag_name, 1, true);

    // Virtual method
    var virtual_method_name = StringName.fromComptimeLatin1("_my_virtual_method");
    ClassDB.registerVirtualMethod(&class_name, .{
        .name = &virtual_method_name,
        .return_value = .{ .type = .int },
    });
}

fn callIncrement(instance: *TestNode, _: []const *const Variant) godot.CallError!Variant {
    instance.increment();
    return Variant.nil;
}

fn callGetCounter(instance: *TestNode, _: []const *const Variant) godot.CallError!Variant {
    return Variant.init(instance.getCounter());
}

fn callAddValue(instance: *TestNode, args: []const *const Variant) godot.CallError!Variant {
    if (args.len < 1) return error.TooFewArguments;
    const value = args[0].as(i64) orelse return error.InvalidArgument;
    return Variant.init(instance.addValue(value));
}

fn callGetMyProperty(instance: *TestNode, _: []const *const Variant) godot.CallError!Variant {
    return Variant.init(instance.getMyProperty());
}

fn callSetMyProperty(instance: *TestNode, args: []const *const Variant) godot.CallError!Variant {
    if (args.len < 1) return error.TooFewArguments;
    const value = args[0].as(i64) orelse return error.InvalidArgument;
    instance.setMyProperty(value);
    return Variant.nil;
}

fn callGetIndexedValue(instance: *TestNode, args: []const *const Variant) godot.CallError!Variant {
    if (args.len < 1) return error.TooFewArguments;
    const index = args[0].as(i64) orelse return error.InvalidArgument;
    return Variant.init(instance.getIndexedValue(index));
}

fn callSetIndexedValue(instance: *TestNode, args: []const *const Variant) godot.CallError!Variant {
    if (args.len < 2) return error.TooFewArguments;
    const index = args[0].as(i64) orelse return error.InvalidArgument;
    const value = args[1].as(i64) orelse return error.InvalidArgument;
    instance.setIndexedValue(index, value);
    return Variant.nil;
}

const godot = @import("gdzig");
const ClassDB = godot.class.ClassDB;
const Node = godot.class.Node;
const String = godot.builtin.String;
const StringName = godot.builtin.StringName;
const Variant = godot.builtin.Variant;

const testing = @import("gdzig_test");
