# amistozy/sml

`amistozy/sml` is an S-expression-based ML-like language implemented in
MoonBit.

The package is both a small runnable language and a compact example of how to
build a parser, a surface language, a lowering pass, and an evaluator in
MoonBit.

## Pipeline

The implementation is organized as a simple pipeline:

- parse source text into `SExpr`
- parse `SExpr` into `SurfaceExpr`
- lower `SurfaceExpr` into `CoreExpr`
- evaluate `CoreExpr` into `Value`

The public API exposes each stage, so you can inspect intermediate forms as
well as run complete programs.

## Public API

- `parse_sexp(source) -> SExpr`
- `parse_surface(source) -> SurfaceExpr`
- `parse_surface_expr(expr) -> SurfaceExpr`
- `desugar(expr) -> CoreExpr`
- `lower(source) -> CoreExpr`
- `eval_core(expr) -> Value`
- `run(source) -> Value`
- `run_to_string(source) -> String`

## Quick Example

The following program is a version of Knuth's "Man or Boy" test:

```moonbit nocheck
///|
test "Man or Boy test" {
  let program =
    #|(letrec (a k x1 x2 x3 x4 x5)
    #|  (let m (ref k))
    #|  (letrec (b)
    #|    (%= m (- _ 1))
    #|    (a (! m) b x1 x2 x3 x4))
    #|  (if (<= k 0) (+ (x4) (x5)) (b)))
    #|
    #|(a 10 (do 1) (do -1) (do -1) (do 1) (do 0))

  assert_eq(@sml.run_to_string(program), "-67")
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

Functions are non-curried: one call supplies the full parameter list.

### Blocks

`begin` is the explicit block form. A block evaluates its forms in order and
returns the value of the last expression. If the final form is a declaration,
the block evaluates to `()`.

```lisp
(begin
  (let x 1)
  (say x)
  (let y (+ x 1))
  (+ x y))
```

Blocks are also used inside function bodies and declaration right-hand sides.

### Zero-Argument Function Sugar

`do` is sugar for a zero-argument function:

```lisp
(let next
  (do
    (let x 1)
    (+ x 2)))

(next)
```

This is equivalent to:

```lisp
(let next
  (fn ()
    (let x 1)
    (+ x 2)))

(next)
```

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

Recursive function declarations:

```lisp
(letrec (fact n)
  (if (= n 0)
    1
    (* n (fact (- n 1)))))

(fact 5)
```

Mutually recursive function declarations:

```lisp
(letrec&
  ((even n)
   (if (= n 0) true (odd (- n 1))))
  ((odd n)
   (if (= n 0) false (even (- n 1)))))

(even 10)
```

### Ignored Bindings

`_` means "ignore this binding" when it appears in binding position:

```lisp
(let _ 42)
((fn (x _ z) (+ x z)) 1 999 2)
```

Ignored bindings are not inserted into the runtime environment.

### Placeholder Lambda Shorthand

In expression position, `_` is a placeholder for a single implicit argument.
The smallest `if` or function call that directly contains `_` is rewritten into
a one-argument function.

```lisp
(+ _ 1)
```

expands to:

```lisp
(fn (__arg) (+ __arg 1))
```

Repeated placeholders within the same shorthand expression all refer to the
same argument:

```lisp
(+ _ _)
```

expands to:

```lisp
(fn (__arg) (+ __arg __arg))
```

Nested shorthand is expanded bottom-up. For example:

```lisp
(+ 1 (* _ 2))
```

becomes:

```lisp
(+ 1 (fn (__arg) (* __arg 2)))
```

A bare `_` is not a valid complete expression.

## Built-in Functions

The runtime currently provides:

- Arithmetic: `+`, `-`, `*`, `/`
- Concatenation: `++`
- Comparison: `=`, `<`, `>`, `<=`, `>=`
- Boolean: `not`
- References: `ref`, `!`, `:=`, `%=` 
- Output: `say`

### Arithmetic

`+` performs integer addition:

```lisp
(+ 1 2 3)
```

`++` concatenates values by converting each argument to text first:

```lisp
(++ "foo" "bar" "baz")
(++ "age: " 18)
```

### Output

`say` accepts zero or more arguments and prints them separated by a single
space.

```lisp
(let name "Alice")
(let age 18)
(say name "is" age "years old.")
```

### References

References are mutable cells:

```lisp
(let r (ref 1))
(! r)
(:= r 2)
(! r)
```

`%=` updates a reference by applying a unary function to its current value:

```lisp
(let r (ref 42))
(%= r (+ _ 1))
(! r)
```

## CLI

The repository includes a CLI in `cmd/main` with subcommands for each pipeline
stage.

Evaluate an inline program:

```bash
moon run cmd/main -- run -e "(+ 1 (* 2 3) 4)"
```

Evaluate a program from a file:

```bash
moon run cmd/main -- run play.sml
```

Inspect the parsed S-expression tree:

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

Each subcommand accepts exactly one input source:

- `-e <expr>` reads source from the command line
- `<path>` reads source from a file

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

VS Code syntax highlighting lives in `vscode-extension/`.

## Notes

- Comments start with `;` and continue to the end of the line
- String literals support `\n`, `\r`, `\t`, `\"`, and `\\`
- Errors are reported as `SmlError`, with parse, surface, and runtime variants
