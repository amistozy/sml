# amistozy/sml

`amistozy/sml` is an S-expression-based ML-like language implemented in
MoonBit. In this project, `SML` stands for "S-expression-based ML-like
language". It includes a parser, a surface syntax layer, a desugaring step,
and a runtime evaluator. The project is useful both as a compact language
implementation and as a playground for experimenting with parsing and
evaluation pipelines.

## Features

- Parses S-expressions into a structured AST
- Supports integers, booleans, strings, variables, functions, calls, and `if`
- Supports multi-form blocks and declaration sequences
- Provides sequential `let` and parallel `let&` bindings
- Uses lexical closures with immutable environments
- Exposes each compilation stage as public functions

## Public API

The package exposes the following main entry points:

- `parse_sexp(source)` parses raw source into `SExpr`
- `parse_surface(source)` parses source into `SurfaceExpr`
- `desugar(expr)` lowers surface syntax into `CoreExpr`
- `eval_core(expr)` evaluates core expressions
- `run(source)` parses, desugars, and evaluates the program
- `run_to_string(source)` evaluates and renders the final value

## Example

```moonbit
test "run a simple program" {
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

Functions are non-curried: all parameters are passed at once.

### Blocks

When multiple top-level forms appear together, they are treated as a block.
The last expression becomes the result. If a block ends with a declaration, the
result is `()`.

```lisp
(let x 1)
(println x)
(let y (+ x 1))
(+ x y)
```

The same block-style body also works inside `fn` and `do`.

### Bindings

Sequential binding:

```lisp
(let x 10)
(let y (+ x 5))
(+ x y)
```

Parallel binding:

```lisp
(let& (x 1) (y 2))
(+ x y)
```

`let&` evaluates every right-hand side in the original environment, so sibling
bindings do not see one another.

## Built-in Functions

The runtime currently provides:

- Arithmetic: `+`, `-`, `*`, `/`
- Comparison: `=`, `<`, `>`, `<=`, `>=`
- Boolean: `not`
- Output: `println`

## CLI

A small runnable entry point is included:

```bash
moon run cmd/main -- "(+ 1 (* 2 3) 4)"
```

If evaluation succeeds, the CLI prints the final result. If it fails, it prints
the reported error.

## Development

Format the project:

```bash
moon fmt
```

Refresh the generated package interface:

```bash
moon info
```

Run tests:

```bash
moon test
```

## Notes

- Comments start with `;` and continue to the end of the line
- String literals support common escapes such as `\n`, `\r`, `\t`, `\"`, and `\\`
- Runtime errors, parse errors, and surface-syntax errors are reported through
  `SmlError`
