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
test "function let declaration parses as fn sugar" {
  let program =
    #|(let (greet name)
    #|  (++ "hello, " name))
    #|(greet "Alice")
  let surface = parse_surface(program)
  assert_true(
    surface
    is Block(
      [
        Decl(
          SurfaceDecl::Let(
            "greet",
            Fn(["name"], Call(Var("++"), [String("hello, "), Var("name")]))
          )
        ),
        Expr(Call(Var("greet"), [String("Alice")])),
      ]
    ),
  )
}

///|
test "empty bodies parse as empty blocks" {
  let let_surface = parse_surface("(let x)")
  let begin_surface = parse_surface_expr(parse_sexp("(begin)"))
  let do_surface = parse_surface_expr(parse_sexp("(do)"))
  let fn_surface = parse_surface_expr(parse_sexp("(fn ())"))
  let let_and_surface = parse_surface("(let& (x))")
  assert_true(let_surface is Block([Decl(SurfaceDecl::Let("x", Block([])))]))
  assert_true(begin_surface is Block([]))
  assert_true(do_surface is Fn([], Block([])))
  assert_true(fn_surface is Fn([], Block([])))
  assert_true(
    let_and_surface is Block([Decl(SurfaceDecl::LetAnd([("x", Block([]))]))]),
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
test "function let and binding parses as fn sugar" {
  let program =
    #|(let& ((double x) (+ x x))
    #|      ((describe x) (++ "value=" x)))
    #|(++ (describe 21) ":" (double 21))
  let surface = parse_surface(program)
  assert_true(
    surface
    is Block(
      [
        Decl(
          SurfaceDecl::LetAnd(
            [
              ("double", Fn(["x"], Call(Var("+"), [Var("x"), Var("x")]))),
              (
                "describe",
                Fn(["x"], Call(Var("++"), [String("value="), Var("x")])),
              ),
            ]
          )
        ),
        Expr(
          Call(
            Var("++"),
            [
              Call(Var("describe"), [Int(21)]),
              String(":"),
              Call(Var("double"), [Int(21)]),
            ]
          )
        ),
      ]
    ),
  )
}

///|
test "letrec declaration parses as recursive function binding" {
  let program =
    #|(letrec (fact n)
    #|  (if (= n 0) 1 (* n (fact (- n 1)))))
    #|(fact 5)
  let surface = parse_surface(program)
  assert_true(
    surface
    is Block(
      [
        Decl(
          SurfaceDecl::LetRec(
            "fact",
            ["n"],
            If(
              Call(Var("="), [Var("n"), Int(0)]),
              Int(1),
              Call(
                Var("*"),
                [
                  Var("n"),
                  Call(Var("fact"), [Call(Var("-"), [Var("n"), Int(1)])]),
                ]
              )
            )
          )
        ),
        Expr(Call(Var("fact"), [Int(5)])),
      ]
    ),
  )
}

///|
test "letrec declaration desugars to core letrec" {
  let program =
    #|(letrec (inc x) (+ x 1))
    #|(inc 41)
  let core = parse_surface(program) |> desugar
  assert_true(
    core
    is LetRec(
      [("inc", ["x"], Call(Var("+"), [Var("x"), Int(1)]))],
      Call(Var("inc"), [Int(41)])
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
test "function let declaration desugars through fn body" {
  let program =
    #|(let (inc x) (+ x 1))
    #|(inc 41)
  let core = parse_surface(program) |> desugar
  assert_true(
    core
    is Let(
      [("inc", Fn(["x"], Call(Var("+"), [Var("x"), Int(1)])))],
      Call(Var("inc"), [Int(41)])
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
test "ref primitives parse as ordinary calls" {
  let program =
    #|(begin
    #|  (:= r (ref 1))
    #|  (! r))
  let surface = parse_surface(program)
  assert_true(
    surface
    is Block(
      [
        Expr(Call(Var(":="), [Var("r"), Call(Var("ref"), [Int(1)])])),
        Expr(Call(Var("!"), [Var("r")])),
      ]
    ),
  )
}

///|
test "percent equals parses as ordinary call" {
  let surface = parse_surface_expr(parse_sexp("(%= r (+ _ 1))"))
  assert_true(
    surface
    is Call(
      Var("%="),
      [Var("r"), Fn(["__arg"], Call(Var("+"), [Var("__arg"), Int(1)]))]
    ),
  )
}

///|
test "placeholder shorthand expands to single argument fn" {
  let surface = parse_surface_expr(parse_sexp("(+ _ 1)"))
  assert_true(surface is Fn(["__arg"], Call(Var("+"), [Var("__arg"), Int(1)])))
}

///|
test "placeholder shorthand reuses one argument for repeated placeholders" {
  let surface = parse_surface_expr(parse_sexp("(+ _ _)"))
  assert_true(
    surface is Fn(["__arg"], Call(Var("+"), [Var("__arg"), Var("__arg")])),
  )
}

///|
test "placeholder shorthand only wraps the smallest nested call" {
  let surface = parse_surface_expr(parse_sexp("(+ 1 (* _ 2))"))
  assert_true(
    surface
    is Call(
      Var("+"),
      [Int(1), Fn(["__arg"], Call(Var("*"), [Var("__arg"), Int(2)]))]
    ),
  )
}

///|
test "underscore binding is preserved in surface fn params" {
  let surface = parse_surface_expr(parse_sexp("(fn (x _ z) (+ x z))"))
  assert_true(
    surface is Fn(["x", "_", "z"], Call(Var("+"), [Var("x"), Var("z")])),
  )
}

///|
test "do parses as zero argument lambda sugar" {
  let surface = parse_surface_expr(parse_sexp("(do (let x 1) (+ x 2))"))
  assert_true(
    surface
    is Fn(
      [],
      Block(
        [
          Decl(SurfaceDecl::Let("x", Int(1))),
          Expr(Call(Var("+"), [Var("x"), Int(2)])),
        ]
      )
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
