///|
test "evaluate arithmetic and nested calls" {
  let program =
    #|(+ 1 (* 2 3) 4)
  assert_eq(@sml.run_to_string(program), "11")
}

///|
test "double plus concatenates strings" {
  let program =
    #|(++ "foo" "bar" "baz")
  assert_eq(@sml.run_to_string(program), "\"foobarbaz\"")
}

///|
test "double plus stringifies non string arguments" {
  let program =
    #|(++ "foo" 1 true)
  assert_eq(@sml.run_to_string(program), "\"foo1true\"")
}

///|
test "plus rejects string arguments" {
  let program =
    #|(+ "foo" 1)
  let result = try? @sml.run_to_string(program)
  assert_true(result is Err(@sml.RuntimeError(_)))
}

///|
test "parallel let evaluates rhs in original environment" {
  let program =
    #|(let& (x 10) (y (+ x 5)))
    #|(+ x y)
  let result = try? @sml.run_to_string(program)
  assert_true(result is Err(@sml.RuntimeError(_)))
}

///|
test "block with let declarations computes final expression" {
  let program =
    #|(let x 10)
    #|(let y (+ x 5))
    #|(+ x y)
  assert_eq(@sml.run_to_string(program), "25")
}

///|
test "let declaration rhs can contain multiple forms" {
  let program =
    #|(let x
    #|  (let y 42)
    #|  (* y 2))
    #|(+ 1 x)
  assert_eq(@sml.run_to_string(program), "85")
}

///|
test "let function declaration sugar works" {
  let program =
    #|(let (greet name)
    #|  (++ "hello, " name))
    #|(greet "Alice")
  assert_eq(@sml.run_to_string(program), "\"hello, Alice\"")
}

///|
test "empty bodies evaluate to unit" {
  let program =
    #|(let x)
    #|(let (f))
    #|(begin)
    #|((fn ()))
  assert_eq(@sml.run_to_string(program), "()")
}

///|
test "let and function declaration sugar works" {
  let program =
    #|(let& ((double x) (+ x x))
    #|      ((describe x) (++ "value=" x)))
    #|(++ (describe 21) ":" (double 21))
  assert_eq(@sml.run_to_string(program), "\"value=21:42\"")
}

///|
test "letrec supports self recursion" {
  let program =
    #|(letrec (fact n)
    #|  (if (= n 0)
    #|    1
    #|    (* n (fact (- n 1)))))
    #|(fact 5)
  assert_eq(@sml.run_to_string(program), "120")
}

///|
test "letrec and supports mutual recursion" {
  let program =
    #|(letrec& ((even n)
    #|           (if (= n 0)
    #|             true
    #|             (odd (- n 1))))
    #|          ((odd n)
    #|           (if (= n 0)
    #|             false
    #|             (even (- n 1)))))
    #|(even 10)
  assert_eq(@sml.run_to_string(program), "true")
}

///|
test "block can interleave expressions and let declarations" {
  let program =
    #|(let x 1)
    #|(+ x 10)
    #|(let y (+ x 1))
    #|(+ x y)
  assert_eq(@sml.run_to_string(program), "3")
}

///|
test "let and bindings can use multi form rhs" {
  let program =
    #|(let& (x
    #|        (let y 40)
    #|        (+ y 2))
    #|      (z
    #|        (let w 1)
    #|        (+ w 2)))
    #|(+ x z)
  assert_eq(@sml.run_to_string(program), "45")
}

///|
test "block ending in declaration returns unit" {
  let program =
    #|(let x 1)
    #|(let y (+ x 1))
  assert_eq(@sml.run_to_string(program), "()")
}

///|
test "non curried closures capture environment" {
  let program =
    #|((fn (x y z) (+ x y z)) 4 5 3)
  assert_eq(@sml.run_to_string(program), "12")
}

///|
test "block can appear in function body" {
  let program =
    #|((fn ()
    #|   (let x 1)
    #|   (say x)
    #|   (let y (+ x 1))
    #|   (+ x y)))
  assert_eq(@sml.run_to_string(program), "3")
}

///|
test "block can appear in begin" {
  let program =
    #|(begin
    #|  (let x 1)
    #|  (say x)
    #|  (let y (+ x 1))
    #|  (+ x y))
  assert_eq(@sml.run_to_string(program), "3")
}

///|
test "say accepts multiple arguments" {
  let program =
    #|(let name "Alice")
    #|(let age 18)
    #|(say name "is" age "years old.")
    #|age
  assert_eq(@sml.run_to_string(program), "18")
}

///|
test "if and begin work together" {
  let program =
    #|(begin
    #|  (if (> 3 2) 7 8)
    #|  (if (not false) 9 0))
  assert_eq(@sml.run_to_string(program), "9")
}

///|
test "do is zero argument lambda sugar" {
  let program =
    #|((do
    #|   (let x 1)
    #|   (+ x 2)))
  assert_eq(@sml.run_to_string(program), "3")
}

///|
test "strings are dynamic values too" {
  let program =
    #|(if (= "hi" "hi") "ok" "bad")
  assert_eq(@sml.run_to_string(program), "\"ok\"")
}

///|
test "ref supports create read and write" {
  let program =
    #|(let r (ref 1))
    #|(:= r 2)
    #|(! r)
  assert_eq(@sml.run_to_string(program), "2")
}

///|
test "ref aliases are shared" {
  let program =
    #|(let r (ref 1))
    #|(let s r)
    #|(:= s 7)
    #|(! r)
  assert_eq(@sml.run_to_string(program), "7")
}

///|
test "ref updates are visible through closures" {
  let program =
    #|(let r (ref 0))
    #|(let (bump)
    #|  (:= r (+ (! r) 1)))
    #|(bump)
    #|(! r)
  assert_eq(@sml.run_to_string(program), "1")
}

///|
test "deref rejects non refs" {
  let result = try? @sml.run_to_string("(! 1)")
  assert_true(result is Err(@sml.RuntimeError(_)))
}

///|
test "placeholder shorthand builds a single argument lambda" {
  let program =
    #|((+ _ 1) 41)
  assert_eq(@sml.run_to_string(program), "42")
}

///|
test "placeholder shorthand only rewrites the innermost expression" {
  let program =
    #|(let add1 (+ _ 1))
    #|(add1 41)
  assert_eq(@sml.run_to_string(program), "42")
}

///|
test "placeholder shorthand wraps the smallest nested call" {
  let program =
    #|(let (apply f)
    #|  (+ 1 (f 21)))
    #|(apply (* _ 2))
  assert_eq(@sml.run_to_string(program), "43")
}

///|
test "placeholder shorthand wraps nested argument expressions" {
  let program =
    #|(let pred (> _ 0))
    #|(if (pred 1) 7 8)
  assert_eq(@sml.run_to_string(program), "7")
}

///|
test "placeholder shorthand reuses the same argument for repeated placeholders" {
  let program =
    #|((+ _ _) 21)
  assert_eq(@sml.run_to_string(program), "42")
}

///|
test "placeholder shorthand rejects a bare underscore expression" {
  let result = try? @sml.run_to_string("_")
  assert_true(result is Err(@sml.SurfaceError(_)))
}

///|
test "underscore let binding ignores the bound value" {
  let program =
    #|(let x 1)
    #|(let _ 2)
    #|x
  assert_eq(@sml.run_to_string(program), "1")
}

///|
test "underscore function parameter is ignored" {
  let program =
    #|(let x 10)
    #|((fn (_ y) (+ x y)) 99 2)
  assert_eq(@sml.run_to_string(program), "12")
}
