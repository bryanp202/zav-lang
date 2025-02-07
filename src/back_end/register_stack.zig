// Imports
const std = @import("std");
const Error = @import("../error.zig");
const GenerationError = Error.GenerationError;

/// Container used to cache a registers location and name in reg_name array
pub const Register = struct {
    name: []const u8,
    index: usize,
};

/// Used to store what registers are active and allows
/// simple stack operations like pop, push, and load new
pub fn RegisterStack(name_list: anytype) type {
    return struct {
        const Self = @This();
        /// Stores the all register names
        const reg_names = name_list;

        /// Marks which of the available register names are in use
        active_reg: [name_list.len]bool,
        /// Stores the currentlu active registers
        reg_stack: [name_list.len]Register,
        /// How many active registers
        count: usize,

        pub fn init() Self {
            return Self{
                .active_reg = [_]bool{false} ** Self.reg_names.len,
                .reg_stack = [_]Register{undefined} ** Self.reg_names.len,
                .count = 0,
            };
        }

        /// Push the inputted register onto the stack
        pub fn push(self: *Self, reg: Register) void {
            // Mark register as active
            self.active_reg[reg.index] = true;

            // Put name on stack
            self.reg_stack[self.count] = reg;
            // Increment
            self.count += 1;
        }

        /// Pop the top reg, marking it as inactive
        pub fn pop(self: *Self) Register {
            // Deincrement
            self.count -= 1;
            // Get the register on top
            const pop_reg = self.reg_stack[self.count];
            // Mark it as not in use
            self.active_reg[pop_reg.index] = false;
            // Return it
            return pop_reg;
        }

        /// Returns the current register
        pub fn current(self: *Self) Register {
            return self.reg_stack[self.count - 1];
        }

        /// Load a new register that is not in use onto the stack
        pub fn loadNew(self: *Self) GenerationError!Register {
            for (&self.active_reg, 0..) |*curr_reg, index| {
                // If not in use
                if (!curr_reg.*) {
                    // Mark as in use
                    curr_reg.* = true;
                    // Get the name it corresponds to
                    const reg_name = Self.reg_names[index];
                    // Make a new register
                    const new_reg = Register{ .index = index, .name = reg_name };

                    // Push it onto the stack
                    self.reg_stack[self.count] = new_reg;
                    // Increment
                    self.count += 1;

                    // Return it
                    return new_reg;
                }
            }
            // Else ran out of registers
            return GenerationError.OutOfRegisters;
        }
    };
}
