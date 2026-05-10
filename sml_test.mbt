///|
test "evaluate arithmetic and nested calls" {
  let program =
    #|(+ 1 (* 2 3) 4)
  assert_eq(@sml.run_to_string(program), "11")
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
test "block can appear in do" {
  let program =
    #|(do
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
test "if and do work together" {
  let program =
    #|(do
    #|  (if (> 3 2) 7 8)
    #|  (if (not false) 9 0))
  assert_eq(@sml.run_to_string(program), "9")
}

///|
test "strings are dynamic values too" {
  let program =
    #|(if (= "hi" "hi") "ok" "bad")
  assert_eq(@sml.run_to_string(program), "\"ok\"")
}
