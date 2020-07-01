const std = @import("std");
const aya = @import("aya");

const Writer = aya.mem.SdlBufferStream.Writer;
const Reader = aya.mem.SdlBufferStream.Reader;
const Map = @import("data.zig").Map;
const Rule = @import("data.zig").Rule;
const RuleTile = @import("data.zig").RuleTile;

pub fn save(map: Map, file: []const u8) !void {
    var path_or_null = try @import("known-folders.zig").getPath(aya.mem.tmp_allocator, .desktop);
    const out_path = try std.fs.path.join(aya.mem.tmp_allocator, &[_][]const u8{ path_or_null.?, "tilekit.bin" });

    var buf = aya.mem.SdlBufferStream.init(out_path, .write);
    defer buf.deinit();

    const out = buf.writer();
    try out.writeIntLittle(i32, map.w);
    try out.writeIntLittle(i32, map.h);
    try out.writeIntLittle(i32, map.tile_size);
    try out.writeIntLittle(i32, map.tile_spacing);
    try out.writeIntLittle(usize, map.image.len);
    try out.writeAll(map.image);

    const data_bytes = std.mem.sliceAsBytes(map.data);
    try out.writeIntLittle(usize, data_bytes.len);
    try out.writeAll(data_bytes);

    try out.writeIntLittle(usize, map.rules.items.len);
    for (map.rules.items) |rule| {
        try writeRule(out, rule);
    }

    try out.writeIntLittle(usize, map.pre_rules.items.len);
    for (map.pre_rules.items) |rule_page| {
        try out.writeIntLittle(usize, rule_page.items.len);
        for (rule_page.items) |rule| {
            try writeRule(out, rule);
        }
    }
}

fn writeRule(out: Writer, rule: Rule) !void {
    const name = rule.name[0..std.mem.indexOfSentinel(u8, 0, rule.name[0..])];
    try out.writeIntLittle(usize, name.len);
    try out.writeAll(name);

    for (rule.pattern_data) |rule_tile| {
        try out.writeIntLittle(usize, rule_tile.tile);
        try out.writeIntLittle(u8, @enumToInt(rule_tile.state));
    }

    try out.writeIntLittle(u8, rule.chance);

    try out.writeIntLittle(usize, rule.selected_data.len);
    for (rule.selected_data.items) |selected_data, i| {
        if (i == rule.selected_data.len) break;
        try out.writeIntLittle(u8, selected_data);
    }
}

pub fn load(file: []const u8) !Map {
    var path_or_null = try @import("known-folders.zig").getPath(aya.mem.tmp_allocator, .desktop);
    const out_path = try std.fs.path.join(aya.mem.tmp_allocator, &[_][]const u8{ path_or_null.?, "tilekit.bin" });

    var buf = aya.mem.SdlBufferStream.init(out_path, .read);
    defer buf.deinit();

    var map = Map{
        .data = undefined,
        .rules = std.ArrayList(Rule).init(aya.mem.allocator),
        .pre_rules = std.ArrayList(std.ArrayList(Rule)).init(aya.mem.allocator),
    };

    // std.mem.bytesAsValue for reading f32
    const in = buf.reader();
    map.w = try in.readIntLittle(i32);
    map.h = try in.readIntLittle(i32);
    map.tile_size = try in.readIntLittle(i32);
    map.tile_spacing = try in.readIntLittle(i32);

    var image_len = try in.readIntLittle(usize);
    if (image_len > 0) {
        const buffer = try aya.mem.tmp_allocator.alloc(u8, image_len);
        _ = try in.readAll(buffer);
        map.image = buffer;
    }

    const data_len = try in.readIntLittle(usize);
    const data_as_bytes = try aya.mem.allocator.alignedAlloc(u8, @alignOf(u32), data_len);
    _ = try in.readAll(data_as_bytes);
    map.data = std.mem.bytesAsSlice(u32, data_as_bytes);

    std.debug.print("{}, {}, {}, {} img.len: {}, data.len: {}\n", .{ map.w, map.h, map.tile_size, map.tile_spacing, image_len, data_len });

    const rules_len = try in.readIntLittle(usize);
    _ = try map.rules.ensureCapacity(rules_len);
    var i: usize = 0;
    while (i < rules_len) : (i += 1) {
        try map.rules.append(try readRule(in));
    }

    const pre_rules_pages = try in.readIntLittle(usize);
    std.debug.print("pages: {}\n", .{pre_rules_pages});
    _ = try map.pre_rules.ensureCapacity(pre_rules_pages);
    i = 0;
    while (i < pre_rules_pages) : (i += 1) {
        _ = try map.pre_rules.append(std.ArrayList(Rule).init(aya.mem.allocator));

        const rules_cnt = try in.readIntLittle(usize);
        _ = try new_page.ensureCapacity(rules_cnt);
        var j: usize = 0;
        while (j < rules_cnt) : (j += 1) {
            try map.pre_rules.items[i].append(try readRule(in));
        }
        std.debug.print("--- rules on page: {}\n", .{rules_cnt});
    }

    return map;
}

fn readRule(in: Reader) !Rule {
    var rule = Rule.init();

    const name_len = try in.readIntLittle(usize);
    const buffer = try aya.mem.tmp_allocator.alloc(u8, name_len);
    _ = try in.readAll(buffer);
    std.mem.copy(u8, rule.name[0..], buffer);

    for (rule.pattern_data) |*rule_tile| {
        rule_tile.tile = try in.readIntLittle(usize);
        rule_tile.state = @intToEnum(RuleTile.RuleTileState, @intCast(u4, try in.readIntLittle(u8)));
    }

    rule.chance = try in.readIntLittle(u8);

    const selected_len = try in.readIntLittle(usize);
    var i: usize = 0;
    while (i < selected_len) : (i += 1) {
        rule.selected_data.append(try in.readIntLittle(u8));
    }

    return rule;
}

/// deprecated
pub fn toJson(map: Map) !void {
    var path_or_null = try @import("known-folders.zig").getPath(aya.mem.tmp_allocator, .desktop);
    const out_path = try std.mem.concat(aya.mem.tmp_allocator, u8, &[_][]const u8{ path_or_null.?, "/", "tilekit.json" });

    var buf = aya.mem.SdlBufferStream.init(out_path, .write);
    defer buf.deinit();
    const out_stream = buf.writer();

    var jw = std.json.writeStream(out_stream, 10);

    try jw.beginObject();
    try jw.objectField("w");
    try jw.emitNumber(map.w);

    try jw.objectField("h");
    try jw.emitNumber(map.h);

    try jw.objectField("tile_size");
    try jw.emitNumber(map.tile_size);

    try jw.objectField("tile_spacing");
    try jw.emitNumber(map.tile_spacing);

    try jw.objectField("image");
    try jw.emitString(map.image);

    try jw.objectField("data");
    try jw.beginArray();
    for (map.data) |d| {
        try jw.arrayElem();
        try jw.emitNumber(d);
    }
    try jw.endArray();

    try jw.objectField("rules");
    try jw.beginArray();
    for (map.rules.items) |rule| {
        try jw.arrayElem();
        try jw.beginObject();
        try jw.objectField("name");
        try jw.emitString(rule.name[0..std.mem.indexOfSentinel(u8, 0, rule.name[0..])]);

        try jw.objectField("chance");
        try jw.emitNumber(rule.chance);

        try jw.objectField("pattern_data");
        try jw.beginArray();
        for (rule.pattern_data) |rule_tile| {
            try jw.arrayElem();
            try jw.beginObject();
            try jw.objectField("tile");
            try jw.emitNumber(rule_tile.tile);
            try jw.objectField("state");
            try jw.emitNumber(@enumToInt(rule_tile.state));
            try jw.endObject();
        }
        try jw.endArray();

        try jw.objectField("selected_data");
        try jw.beginArray();
        for (rule.selected_data.items) |selected_data, i| {
            if (i == rule.selected_data.len) break;
            try jw.arrayElem();
            try jw.emitNumber(selected_data);
        }
        try jw.endArray();

        try jw.endObject();
    }
    try jw.endArray();

    try jw.endObject();
}
