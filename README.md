# What is Zav?
A custom compiler developed as a learning experiment for compiler design and the relatively new language Zig. Zav is a low-level language that supports functions and structs with methods, but requires manual memory management similar to C and Zig. The syntax is a cross between C and Zig, but has some novel features as well. There is limited interfacing available with operating systems through "native" function calls, but Zav is currently limited to the Windows platform as well as the x86 architecture. Zac supports type a simplified version of type inferencing, similar to zig and rust, making the process of writing code more streamlined. Zav uses multiple passes, allowing functions, structs, and globals to be declared at any location in the program while being usable anywhere else. This allows circular recursive function calls, circularly nested struct pointers, and several other conveniences.

# Dependencies
Will output a .asm file in NASM format without any dependencies, but will assume NASM and GCC are installed to path in order to output an exe file.

# Zav Language Grammar
### Notation:
- \* Means zero or more
- \+ Means one or more
- \? Means the prior token is optional 
- \| Means logical OR

### Before explaining Zav's grammar, a few common terms must be defined:
#### **Identifier**: [_a-zA-Z] [_a-zA-Z0-9]*
  - A variable, function, method, or arguments identifier
#### **Type/Kind**: Integer | Float | Pointer | Array | Function | Struct | Bool | Void
  - *Integer*: ("i" | "u") ("8" | "16" | "32" | "64")
    - "i" for signed integer; "u" for unsigned integer
    - The number after the signedness defines the number of bytes
  - *Float*: "f" ("32" | "64")
    - Only 32 bit and 64 bit IEEE floating point types are supported
  - *Pointer*: '*' "const"? **Type/Kind**
    - "const" is optional, defines if data can be mutated
    - Ex: *const u8 -> Points to a u8 that cannot be modified from this pointer, only accessed
    - Note: can be nested -> **i64 is a pointer to a pointer of a signed 64 bit integer
  - *Array*: '[' Length ']' "const"? **Type/Kind**
    - "const" is optional, defines if data can be mutated
    - Ex: [10]const u8 -> Is an array of length 10 of u8 values that cannot be modified by access from this array, only read
    - Note: can be nested -> [10][10]i64 is a 2d array of i64 values
  - *Function*: "fn" '(' **Type/Kind** (',' **Type/Kind**)* ')' **Type/Kind**
  - *Struct*: Identifier (note: must be declared using a StructStmt)
  - *Bool*: "bool"
    - Node: can be assigned with "true" or "false"
  - *Void*: "void"
### What is in a program?
Zav currently does not support any form of modules or imports, so everything must be localized to one file. A file will be considered a **program**.
#### **Program**: MainFunction (StructDeclaration | FunctionDefinition | GlobalDeclaration)*
  - *MainFunction*: "fn" main '(' Identifier ':' i64, Identifier ':' **u8 ')' "i64" BlockStmt
#### StructDeclaration
