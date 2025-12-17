const gdzig = @import("gdzig");
const classdb = gdzig.class.ClassDb;
const StringName = gdzig.builtin.StringName;

pub fn registerSignal(comptime T: type, comptime S: type) void {
    const class_name: StringName = .fromType(T);
    const signal_name: StringName = .fromSignal(S);

    const fields = @typeInfo(S).@"struct".fields;
    var arg_info: [fields.len]classdb.PropertyInfo = undefined;
    var names: [fields.len]StringName = undefined;
    inline for (fields, 0..) |field, i| {
        names[i] = .fromComptimeLatin1(field.name);
        arg_info[i] = .{
            .type = .forType(field.type),
            .name = &names[i],
        };
    }

    classdb.registerSignal(&class_name, &signal_name, &arg_info);
}
