# The ZYL Programming Language

A modern systems programming language with C-like syntax and zero-cost abstractions.

## Features

- 🚀 **Performance**: C-level speed, compiles to native code via LLVM
- 🎯 **Simple**: Clean syntax without complexity
- 🔧 **Structs**: With methods and default values
- 🔄 **Memory**: Manual control with malloc/free
- ⚡ **Fast compilation**: Compiles large projects in milliseconds

## Quick Start

```bash
# Build compiler
dub build --compiler=ldc2

# Compile and run
./zyl hello.zyl
./a.out
```

## Example

```c
int printf(string msg, ...);

struct Person {
    string name;
    int age;
    
    void greet(Person* self) {
        printf("Hi, I'm %s, %d years old\n", self.name, self.age)
    }
}

int main() {
    Person p = Person{"Alice", 25}
    p.greet()
    return 0
}
```

## Syntax

- Optional semicolons
- Structs with methods and default values
- For/while loops with break/continue
- Type inference coming soon

## Performance

```
Benchmark: 100M iterations
Zyl:     0.08s  ⚡
Clang: 0.08s  (identical!)
```

## Status

Early development. Core language complete. See `examples/` for more.

## License

MIT
