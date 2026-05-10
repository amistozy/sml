///|
test "parse sexp keeps string and symbol atoms distinct" {
  let program =
    #|(f "x" true 42)
  let sexp = parse_sexp(program)
  assert_true(
    sexp
    is List(
      [Atom(Symbol("f")), Atom(String("x")), Atom(Bool(true)), Atom(Int(42))]
    ),
  )
}

///|
test "single let block desugars to core let" {
  let program =
    #|(let x 1)
    #|(+ x 2)
  let core = parse_surface(program) |> desugar
  assert_true(core is Let([("x", Int(1))], Call(Var("+"), [Var("x"), Int(2)])))
}

///|
test "single let declaration can parse multi form rhs as block" {
  let program =
    #|(let x
    #|  (let y 42)
    #|  (* y 2))
    #|(+ 1 x)
  let surface = parse_surface(program)
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
  let program =
    #|(let x 42)
    #|(say x)
    #|(let y (+ x 1))
    #|(+ x y)
  let surface = parse_surface(program)
  assert_true(
    surface
    is Block(
      [
        Decl(SurfaceDecl::Let("x", Int(42))),
        Expr(Call(Var("say"), [Var("x")])),
        Decl(SurfaceDecl::Let("y", Call(Var("+"), [Var("x"), Int(1)]))),
        Expr(Call(Var("+"), [Var("x"), Var("y")])),
      ]
    ),
  )
}

///|
test "parallel let binding can parse multi form rhs" {
  let program =
    #|(let& (x
    #|        (let y 40)
    #|        (+ y 2))
    #|      (z
    #|        (let w 1)
    #|        (+ w 2)))
    #|(+ x z)
  let surface = parse_surface(program)
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
  let program =
    #|(fn ()
    #|  (let x 1)
    #|  (say x)
    #|  (let y (+ x 1))
    #|  (+ x y))
  let surface = parse_surface_expr(parse_sexp(program))
  assert_true(
    surface
    is Fn(
      [],
      Block(
        [
          Decl(SurfaceDecl::Let("x", Int(1))),
          Expr(Call(Var("say"), [Var("x")])),
          Decl(SurfaceDecl::Let("y", Call(Var("+"), [Var("x"), Int(1)]))),
          Expr(Call(Var("+"), [Var("x"), Var("y")])),
        ]
      )
    ),
  )
}

///|
test "say call keeps all arguments in order" {
  let program =
    #|(say name "is" age "years old.")
  let surface = parse_surface(program)
  assert_true(
    surface
    is Call(
      Var("say"),
      [Var("name"), String("is"), Var("age"), String("years old.")]
    ),
  )
}

///|
test "parallel let declaration desugars to multi binding core let" {
  let program =
    #|(let& (x 1) (y 2))
    #|(+ x y)
  let core = parse_surface(program) |> desugar
  assert_true(
    core
    is Let([("x", Int(1)), ("y", Int(2))], Call(Var("+"), [Var("x"), Var("y")])),
  )
}

///|
test "middle expression desugars to let underscore" {
  let program =
    #|(let x 1)
    #|(say x)
    #|(+ x 1)
  let core = parse_surface(program) |> desugar
  assert_true(
    core
    is Let(
      [("x", Int(1))],
      Let(
        [("_", Call(Var("say"), [Var("x")]))],
        Call(Var("+"), [Var("x"), Int(1)])
      )
    ),
  )
}

///|
test "trailing declaration desugars to unit result" {
  let program =
    #|(let x 1)
    #|(let y (+ x 1))
  let core = parse_surface(program) |> desugar
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
  let program =
    #|((fn (x y) (+ x y)) 1)
  let result = try? run(program)
  assert_true(result is Err(RuntimeError(_)))
}

///|
test "immutable env supports lexical shadowing without parent chain" {
  let program =
    #|(let x 1)
    #|(let f (fn () x))
    #|(let x 2)
    #|(f)
  assert_eq(run_to_string(program), "1")
}
