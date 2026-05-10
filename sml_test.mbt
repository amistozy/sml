///|
test "evaluate arithmetic and nested calls" {
  assert_eq(@sml.run_to_string("(+ 1 (* 2 3) 4)"), "11")
}

///|
test "parallel let evaluates rhs in original environment" {
  let result = try? @sml.run_to_string("(let& (x 10) (y (+ x 5)))\n(+ x y)")
  assert_true(result is Err(@sml.RuntimeError(_)))
}

///|
test "block with let declarations computes final expression" {
  assert_eq(
    @sml.run_to_string(
      (
        #|(let x 10)
        #|(let y (+ x 5))
        #|(+ x y)
      ),
    ),
    "25",
  )
}

///|
test "let declaration rhs can contain multiple forms" {
  assert_eq(
    @sml.run_to_string(
      (
        #|(let x
        #|  (let y 42)
        #|  (* y 2))
        #|(+ 1 x)
      ),
    ),
    "85",
  )
}

///|
test "block can interleave expressions and let declarations" {
  assert_eq(
    @sml.run_to_string(
      (
        #|(let x 1)
        #|(+ x 10)
        #|(let y (+ x 1))
        #|(+ x y)
      ),
    ),
    "3",
  )
}

///|
test "let and bindings can use multi form rhs" {
  assert_eq(
    @sml.run_to_string(
      (
        #|(let& (x
        #|        (let y 40)
        #|        (+ y 2))
        #|      (z
        #|        (let w 1)
        #|        (+ w 2)))
        #|(+ x z)
      ),
    ),
    "45",
  )
}

///|
test "block ending in declaration returns unit" {
  assert_eq(
    @sml.run_to_string(
      (
        #|(let x 1)
        #|(let y (+ x 1))
      ),
    ),
    "()",
  )
}

///|
test "non curried closures capture environment" {
  assert_eq(@sml.run_to_string("((fn (x y z) (+ x y z)) 4 5 3)"), "12")
}

///|
test "block can appear in function body" {
  assert_eq(
    @sml.run_to_string(
      "((fn () (let x 1) (println x) (let y (+ x 1)) (+ x y)))",
    ),
    "3",
  )
}

///|
test "block can appear in do" {
  assert_eq(
    @sml.run_to_string("(do (let x 1) (println x) (let y (+ x 1)) (+ x y))"),
    "3",
  )
}

///|
test "if and do work together" {
  assert_eq(
    @sml.run_to_string("(do (if (> 3 2) 7 8) (if (not false) 9 0))"),
    "9",
  )
}

///|
test "strings are dynamic values too" {
  assert_eq(
    @sml.run_to_string("(if (= \"hi\" \"hi\") \"ok\" \"bad\")"),
    "\"ok\"",
  )
}
