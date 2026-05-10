///|
test "parse sexp keeps string and symbol atoms distinct" {
  let sexp = parse_sexp("(f \"x\" true 42)")
  assert_true(
    sexp
    is List(
      [Atom(Symbol("f")), Atom(String("x")), Atom(Bool(true)), Atom(Int(42))]
    ),
  )
}

///|
test "surface let desugars to nested core lets" {
  let core = parse_surface("(let ((x 1) (y 2)) (+ x y))") |> desugar
  assert_true(
    core
    is Let("x", Int(1), Let("y", Int(2), Call(Var("+"), [Var("x"), Var("y")]))),
  )
}

///|
test "arity mismatch is rejected at runtime" {
  let result = try? run("((fn (x y) (+ x y)) 1)")
  assert_true(result is Err(RuntimeError(_)))
}

///|
test "immutable env supports lexical shadowing without parent chain" {
  assert_eq(
    run_to_string("(let ((x 1)) (let ((f (fn () x))) (let ((x 2)) (f))))"),
    "1",
  )
}
