const std = @import("std");
const Allocator = std.mem.Allocator;

const namespace = struct {
    fn makeItem(comptime T: type) type {
        return union(enum) {
            Vacant: usize,
            Occupied: T,
        };
    }

    fn makeSlab(comptime T: type) type {
        const SlabImpl = struct {
            array: Array,
            len: usize,
            next: usize,

            pub const Item = makeItem(T);
            pub const Array = std.ArrayList(Item);

            const Self = @This();
            pub fn init(alloc: Allocator) Self {
                return Self {
                    .array = Array.init(alloc),
                    .len = 0,
                    .next = 0,
                };
            }

            pub fn initCapacity(alloc: Allocator, cap: usize) Allocator.Error!Self {
                return Self {
                    .array = try Array.initCapacity(alloc, cap),
                    .len = 0,
                    .next = 0,
                };
            }

            pub fn reserve(self: *Self, cap: usize) Allocator.Error!void {
                return self.array.ensureTotalCapacity(cap);
            }
            
            pub fn clone(self: *Self) Allocator.Error!Self {
                return Self {
                    .array = try self.array.clone(),
                    .len = self.len,
                    .next = self.next
                };
            }

            pub fn deinit(self: Self) void {
                self.array.deinit();
            }

            pub fn clear(self: *Self) void {
                self.array.clearRetainingCapacity();
                self.len = 0;
                self.next = 0;
            }

            pub fn insert(self: *Self, value: T) Allocator.Error!usize {
                self.len += 1;
                const idx = self.next;

                if (self.array.items.len == idx) {
                    try self.array.append(.{.Occupied = value});
                    self.next += 1;
                } else {
                    self.next = self.array.items[idx].Vacant;
                    self.array.items[idx] = .{.Occupied = value};
                }

                return idx;
            }

            pub fn remove(self: *Self, key: usize) ?T {
                if (self.array.items.len <= key) return null;

                const item = self.array.items[key];
                if (std.meta.activeTag(item) == .Vacant) return null;
                
                self.array.items[key] = .{.Vacant = self.next};
                self.len -= 1;
                self.next = key;
                return item.Occupied;
            }
        };
        return SlabImpl;
    }
};

pub const Slab = namespace.makeSlab;


// tests
const eql = std.mem.eql;
const test_alloc = std.testing.allocator;
const expect = std.testing.expect;

test "insert" {
    var slab =  Slab(usize).init(test_alloc);
    try expect(try slab.insert(1) == 0);
    try expect(try slab.insert(1) == 1);
    try expect(try slab.insert(4) == 2);
    try expect(try slab.insert(5) == 3);
    try expect(try slab.insert(1) == 4);
    try expect(try slab.insert(4) == 5);
    try expect(slab.len == 6);
    slab.deinit();
}

test "remove" {
    var slab =  Slab(usize).init(test_alloc);
    _ = try slab.insert(1);
    _ = try slab.insert(1);
    _ = try slab.insert(4);
    _ = try slab.insert(5);
    _ = try slab.insert(1);
    _ = try slab.insert(4);
    try expect(slab.len == 6);

    try expect(slab.remove(6) == null);
    try expect(slab.remove(7) == null);
    try expect(slab.remove(8) == null);
    try expect(slab.len == 6);
    try expect(slab.next == 6);

    try expect(slab.remove(2).? == 4);
    try expect(slab.next == 2);
    try expect(slab.remove(4).? == 1);
    try expect(slab.next == 4);
    try expect(slab.remove(1).? == 1);
    try expect(slab.next == 1);
    try expect(slab.len == 3);
    slab.deinit();
}

test "round" {
    var slab =  Slab(usize).init(test_alloc);
    try expect(try slab.insert(1) == 0);
    try expect(slab.next == 1);
    try expect(try slab.insert(1) == 1);
    try expect(slab.next == 2);
    try expect(slab.remove(0).? == 1);
    try expect(slab.next == 0);

    try expect(try slab.insert(4) == 0);
    try expect(slab.next == 2);
    try expect(slab.remove(1).? == 1);
    try expect(slab.next == 1);

    try expect(try slab.insert(5) == 1);
    try expect(slab.next == 2);
    try expect(try slab.insert(1) == 2);
    try expect(slab.next == 3);
    try expect(slab.remove(2).? == 1);
    try expect(slab.next == 2);
    try expect(slab.remove(1).? == 5);
    try expect(slab.next == 1);
    try expect(try slab.insert(4) == 1);
    try expect(slab.next == 2);

    try expect(slab.len == 2);    
    slab.deinit();
}
