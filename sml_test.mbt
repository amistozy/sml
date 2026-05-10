///|
test "evaluate arithmetic and nested calls" {
  assert_eq(@sml.run_to_string("(+ 1 (* 2 3) 4)"), "11")
}

///|
test "let is desugared into lexical bindings" {
  assert_eq(@sml.run_to_string("(let ((x 10) (y (+ x 5))) (+ x y))"), "25")
}

///|
test "non curried closures capture environment" {
  assert_eq(
    @sml.run_to_string("((fn (x y) (let ((z 3)) (+ x y z))) 4 5)"),
    "12",
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
