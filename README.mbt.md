# amistozy/sml

`amistozy/sml` is an S-expression-based ML-like language implemented in
MoonBit. In this project, `SML` means "S-expression-based ML-like language",
not Standard ML.

The package is structured as a small language pipeline:

- parse raw source into S-expressions
- parse S-expressions into a surface language
- lower surface syntax into a small core language
- evaluate core expressions

This makes the project useful both as a runnable language and as a compact
example of parser and evaluator design in MoonBit.

## Features

- S-expression syntax with line comments
- Integers, booleans, strings, variables, functions, calls, and `if`
- Mutable references with `ref`, `!`, and `:=`
- Multi-form blocks
- Sequential `let` declarations
- Parallel `let&` declarations
- Lexical closures with immutable environments
- Single-argument lambda shorthand with `_`
- Public entry points for each compilation stage

## Public API

The package exposes these main functions:

- `parse_sexp(source) -> SExpr`
- `parse_surface(source) -> SurfaceExpr`
- `parse_surface_expr(expr) -> SurfaceExpr`
- `desugar(expr) -> CoreExpr`
- `lower(source) -> CoreExpr`
- `eval_core(expr) -> Value`
- `run(source) -> Value`
- `run_to_string(source) -> String`

## Example

```moonbit nocheck
///|
test "evaluate a small program" {
  let program =
    #|(let x 10)
    #|(let y (+ x 5))
    #|(+ x y)

  assert_eq(@sml.run_to_string(program), "25")
}
```

## Language Overview

### Literals

```lisp
42
true
false
"hello"
```

### Conditionals

```lisp
(if (> 3 2) "yes" "no")
```

### Functions

```lisp
((fn (x y z) (+ x y z)) 4 5 3)
```

Functions are non-curried: arguments are passed in a single call.

### Blocks

Multiple forms at the same level are parsed as a block. The last expression is
the block result. If the final form is a declaration, the block evaluates to
`()`.

```lisp
(let x 1)
(say x)
(let y (+ x 1))
(+ x y)
```

Block bodies are also supported inside `fn` and `do`.

### Bindings

Sequential declarations:

```lisp
(let x 10)
(let y (+ x 5))
(+ x y)
```

Parallel declarations:

```lisp
(let& (x 1) (y 2))
(+ x y)
```

`let&` evaluates all right-hand sides in the original environment, so sibling
bindings cannot refer to one another.

The `_` name is treated specially in binding position and means "ignore this
binding":

```lisp
(let _ 42)
((fn (x _ z) (+ x z)) 1 999 2)
```

In expression position, `_` can appear exactly once inside a compound
expression as shorthand for a single-argument lambda:

```lisp
(+ _ 1)
```

This expands to:

```lisp
(fn (x) (+ x 1))
```

## Built-in Functions

The runtime currently provides:

- Arithmetic: `+`, `-`, `*`, `/`
- Concatenation: `++`
- Comparison: `=`, `<`, `>`, `<=`, `>=`
- Boolean: `not`
- References: `ref`, `!`, `:=`
- Output: `say`

`say` accepts zero or more arguments and prints them separated by a single
space.

```lisp
(let name "Alice")
(let age 18)
(say name "is" age "years old.")
```

`+` is integer addition:

```lisp
(+ 1 2 3)
```

`++` concatenates values by converting each argument to text first:

```lisp
(++ "foo" "bar" "baz")
(++ "age: " 18)
```

References are mutable cells:

```lisp
(let r (ref 1))
(! r)
(:= r 2)
(! r)
```

## CLI

The project includes a CLI package at `cmd/main`. It uses subcommands for each
stage of the pipeline.

Evaluate a program from an inline expression:

```bash
moon run cmd/main -- run -e "(+ 1 (* 2 3) 4)"
```

Evaluate a program from a file:

```bash
moon run cmd/main -- run examples/program.sml
```

Inspect the parsed S-expression AST:

```bash
moon run cmd/main -- sexp -e "(+ 1 2)"
```

Inspect the surface AST:

```bash
moon run cmd/main -- surface -e "(let x 1) (+ x 2)"
```

Inspect the lowered core AST:

```bash
moon run cmd/main -- core -e "(let x 1) (+ x 2)"
```

Each stage accepts exactly one input source:

- `-e <expr>` to read source from the command line
- `<path>` to read source from a file

## Development

Update generated package interfaces:

```bash
moon info
```

Format the project:

```bash
moon fmt
```

Run tests:

```bash
moon test
```

## Notes

- Comments start with `;` and continue to the end of the line
- String literals support `\n`, `\r`, `\t`, `\"`, and `\\`
- Errors are reported as `SmlError`, with parse, surface, and runtime variants
