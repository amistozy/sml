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
test "single let block desugars to core let" {
  let core = parse_surface("(let x 1)\n(+ x 2)") |> desugar
  assert_true(core is Let([("x", Int(1))], Call(Var("+"), [Var("x"), Int(2)])))
}

///|
test "single let declaration can parse multi form rhs as block" {
  let surface = parse_surface(
    (
      #|(let x
      #|  (let y 42)
      #|  (* y 2))
      #|(+ 1 x)
    ),
  )
  assert_true(
    surface
    is Block(
      [
        Decl(
          SurfaceDecl::Let(
            "x",
            Block(
              [
                Decl(SurfaceDecl::Let("y", Int(42))),
                Expr(Call(Var("*"), [Var("y"), Int(2)])),
              ]
            )
          )
        ),
        Expr(Call(Var("+"), [Int(1), Var("x")])),
      ]
    ),
  )
}

///|
test "mixed block parses into stmt list" {
  let surface = parse_surface(
    (
      #|(let x 42)
      #|(println x)
      #|(let y (+ x 1))
      #|(+ x y)
    ),
  )
  assert_true(
    surface
    is Block(
      [
        Decl(SurfaceDecl::Let("x", Int(42))),
        Expr(Call(Var("println"), [Var("x")])),
        Decl(SurfaceDecl::Let("y", Call(Var("+"), [Var("x"), Int(1)]))),
        Expr(Call(Var("+"), [Var("x"), Var("y")])),
      ]
    ),
  )
}

///|
test "parallel let binding can parse multi form rhs" {
  let surface = parse_surface(
    (
      #|(let& (x
      #|        (let y 40)
      #|        (+ y 2))
      #|      (z
      #|        (let w 1)
      #|        (+ w 2)))
      #|(+ x z)
    ),
  )
  assert_true(
    surface
    is Block(
      [
        Decl(
          SurfaceDecl::LetAnd(
            [
              (
                "x",
                Block(
                  [
                    Decl(SurfaceDecl::Let("y", Int(40))),
                    Expr(Call(Var("+"), [Var("y"), Int(2)])),
                  ]
                ),
              ),
              (
                "z",
                Block(
                  [
                    Decl(SurfaceDecl::Let("w", Int(1))),
                    Expr(Call(Var("+"), [Var("w"), Int(2)])),
                  ]
                ),
              ),
            ]
          )
        ),
        Expr(Call(Var("+"), [Var("x"), Var("z")])),
      ]
    ),
  )
}

///|
test "function body with statements parses as block expression" {
  let surface = parse_surface_expr(
    parse_sexp("(fn () (let x 1) (println x) (let y (+ x 1)) (+ x y))"),
  )
  assert_true(
    surface
    is Fn(
      [],
      Block(
        [
          Decl(SurfaceDecl::Let("x", Int(1))),
          Expr(Call(Var("println"), [Var("x")])),
          Decl(SurfaceDecl::Let("y", Call(Var("+"), [Var("x"), Int(1)]))),
          Expr(Call(Var("+"), [Var("x"), Var("y")])),
        ]
      )
    ),
  )
}

///|
test "parallel let declaration desugars to multi binding core let" {
  let core = parse_surface("(let& (x 1) (y 2))\n(+ x y)") |> desugar
  assert_true(
    core
    is Let([("x", Int(1)), ("y", Int(2))], Call(Var("+"), [Var("x"), Var("y")])),
  )
}

///|
test "middle expression desugars to let underscore" {
  let core = parse_surface("(let x 1)\n(println x)\n(+ x 1)") |> desugar
  assert_true(
    core
    is Let(
      [("x", Int(1))],
      Let(
        [("_", Call(Var("println"), [Var("x")]))],
        Call(Var("+"), [Var("x"), Int(1)])
      )
    ),
  )
}

///|
test "trailing declaration desugars to unit result" {
  let core = parse_surface("(let x 1)\n(let y (+ x 1))") |> desugar
  assert_true(
    core
    is Let(
      [("x", Int(1))],
      Let([("y", Call(Var("+"), [Var("x"), Int(1)]))], Unit)
    ),
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
    run_to_string(
      (
        #|(let x 1)
        #|(let f (fn () x))
        #|(let x 2)
        #|(f)
      ),
    ),
    "1",
  )
}
