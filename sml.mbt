///|
pub(all) suberror SmlError {
  ParseError(String)
  SurfaceError(String)
  RuntimeError(String)
} derive(Eq, Debug)

///|
pub enum SAtom {
  Int(Int)
  Bool(Bool)
  String(String)
  Symbol(String)
} derive(Eq, Debug)

///|
pub enum SExpr {
  Atom(SAtom)
  List(Array[SExpr])
} derive(Eq, Debug)

///|
pub enum SurfaceExpr {
  Int(Int)
  Bool(Bool)
  String(String)
  Var(String)
  If(SurfaceExpr, SurfaceExpr, SurfaceExpr)
  Block(Array[SurfaceStmt])
  Fn(Array[String], SurfaceExpr)
  Call(SurfaceExpr, Array[SurfaceExpr])
} derive(Eq, Debug)

///|
pub enum SurfaceDecl {
  Let(String, SurfaceExpr)
  LetAnd(Array[(String, SurfaceExpr)])
  LetRec(String, Array[String], SurfaceExpr)
  LetRecAnd(Array[(String, Array[String], SurfaceExpr)])
} derive(Eq, Debug)

///|
pub enum SurfaceStmt {
  Decl(SurfaceDecl)
  Expr(SurfaceExpr)
} derive(Eq, Debug)

///|
pub enum CoreExpr {
  Int(Int)
  Bool(Bool)
  String(String)
  Unit
  Var(String)
  If(CoreExpr, CoreExpr, CoreExpr)
  Let(Array[(String, CoreExpr)], CoreExpr)
  LetRec(Array[(String, Array[String], CoreExpr)], CoreExpr)
  Fn(Array[String], CoreExpr)
  Call(CoreExpr, Array[CoreExpr])
} derive(Eq, Debug)

///|
pub impl Show for SmlError with output(self, logger) {
  match self {
    ParseError(message) => {
      logger.write_string("parse error: ")
      logger.write_string(message)
    }
    SurfaceError(message) => {
      logger.write_string("surface error: ")
      logger.write_string(message)
    }
    RuntimeError(message) => {
      logger.write_string("runtime error: ")
      logger.write_string(message)
    }
  }
}

///|
pub struct Closure {
  params : Array[String]
  body : CoreExpr
  mut env : Env
}

///|
pub enum Value {
  Int(Int)
  Bool(Bool)
  String(String)
  Unit
  Ref(mut value~ : Value)
  Closure(Closure)
  Builtin(String)
}

///|
type Env = @sorted_map.SortedMap[String, Value]

///|
pub impl Show for Value with output(self, logger) {
  match self {
    Int(value) => logger.write_object(value)
    Bool(value) => logger.write_object(value)
    String(value) => {
      logger.write_string("\"")
      logger.write_string(value)
      logger.write_string("\"")
    }
    Unit => logger.write_string("()")
    Ref(_) as cell => {
      logger.write_string("ref(")
      logger.write_object(cell.value)
      logger.write_string(")")
    }
    Closure(_) => logger.write_string("<fn>")
    Builtin(name) => {
      logger.write_string("<builtin:")
      logger.write_string(name)
      logger.write_string(">")
    }
  }
}

///|
fn is_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
}

///|
fn skip_ws(input : StringView) -> StringView {
  for rest = input {
    match rest {
      [ch, .. tail] if is_space(ch) => continue tail
      [';', .. tail] => continue skip_comment(tail)
      _ => break rest
    }
  }
}

///|
fn skip_comment(input : StringView) -> StringView {
  for rest = input {
    match rest {
      ['\n', .. tail] => break tail
      [_, .. tail] => continue tail
      [] => break rest
    }
  }
}

///|
fn parse_string_literal(
  input : StringView,
) -> (StringView, String) raise SmlError {
  let chars = []
  for rest = input {
    match rest {
      ['"', .. tail] => break (tail, String::from_array(chars))
      ['\\', 'n', .. tail] => {
        chars.push('\n')
        continue tail
      }
      ['\\', 'r', .. tail] => {
        chars.push('\r')
        continue tail
      }
      ['\\', 't', .. tail] => {
        chars.push('\t')
        continue tail
      }
      ['\\', '"', .. tail] => {
        chars.push('"')
        continue tail
      }
      ['\\', '\\', .. tail] => {
        chars.push('\\')
        continue tail
      }
      ['\\', _, ..] => raise ParseError("unsupported string escape")
      [ch, .. tail] => {
        chars.push(ch)
        continue tail
      }
      [] => raise ParseError("unterminated string literal")
    }
  }
}

///|
fn parse_atom_token(token : StringView) -> SAtom raise SmlError {
  match token {
    "true" => Bool(true)
    "false" => Bool(false)
    _ =>
      if is_int_token(token) {
        Int(
          @string.parse_int(token) catch {
            _ => raise ParseError("invalid integer literal: \{token}")
          },
        )
      } else {
        Symbol(token.to_owned())
      }
  }
}

///|
fn is_int_token(token : StringView) -> Bool {
  match token {
    [] => false
    ['-', .. tail] => has_only_digits(tail)
    _ => has_only_digits(token)
  }
}

///|
fn has_only_digits(input : StringView) -> Bool {
  let mut seen = false
  for rest = input {
    match rest {
      [ch, .. tail] if ch >= '0' && ch <= '9' => {
        seen = true
        continue tail
      }
      [] => break seen
      _ => break false
    }
  }
}

///|
fn parse_symbol_or_int(
  input : StringView,
) -> (StringView, SExpr) raise SmlError {
  let chars = []
  for rest = input {
    match rest {
      [] => {
        let token = String::from_array(chars)
        break (rest, Atom(parse_atom_token(token)))
      }
      [ch, ..] if is_space(ch) || ch == '(' || ch == ')' || ch == ';' => {
        let token = String::from_array(chars)
        guard token.length() > 0 else { raise ParseError("expected atom") }
        break (rest, Atom(parse_atom_token(token)))
      }
      [ch, .. tail] => {
        chars.push(ch)
        continue tail
      }
    }
  }
}

///|
fn parse_list(input : StringView) -> (StringView, SExpr) raise SmlError {
  let items = []
  for rest = skip_ws(input) {
    match rest {
      [')', .. tail] => break (tail, List(items))
      [] => raise ParseError("unterminated list")
      _ => {
        let (tail, expr) = parse_sexp_inner(rest)
        items.push(expr)
        continue skip_ws(tail)
      }
    }
  }
}

///|
fn parse_sexp_inner(input : StringView) -> (StringView, SExpr) raise SmlError {
  let rest = skip_ws(input)
  match rest {
    [] => raise ParseError("expected expression")
    ['(', .. tail] => parse_list(tail)
    [')', ..] => raise ParseError("unexpected )")
    ['"', .. tail] => {
      let (rest, value) = parse_string_literal(tail)
      (rest, Atom(String(value)))
    }
    _ => parse_symbol_or_int(rest)
  }
}

///|
pub fn parse_sexp(source : StringView) -> SExpr raise SmlError {
  let (rest, expr) = parse_sexp_inner(source)
  guard skip_ws(rest) is [] else {
    raise ParseError("unexpected trailing input")
  }
  expr
}

///|
fn parse_sexps(source : StringView) -> Array[SExpr] raise SmlError {
  let exprs = []
  for rest = skip_ws(source) {
    match rest {
      [] => break exprs
      _ => {
        let (tail, expr) = parse_sexp_inner(rest)
        exprs.push(expr)
        continue skip_ws(tail)
      }
    }
  }
}

///|
fn expect_symbol_atom(expr : SExpr) -> String raise SmlError {
  match expr {
    Atom(Symbol(name)) => name
    _ => raise SurfaceError("expected symbol")
  }
}

///|
fn parse_params(expr : SExpr) -> Array[String] raise SmlError {
  match expr {
    List(items) => items.map(expect_symbol_atom)
    _ => raise SurfaceError("function parameter list must be a list")
  }
}

///|
fn parse_decl_name_and_value(
  target : SExpr,
  body : ArrayView[SExpr],
) -> (String, SurfaceExpr) raise SmlError {
  match target {
    Atom(Symbol(name)) => (name, parse_body(body))
    List([Atom(Symbol(name)), .. params]) => {
      let params = parse_params(List(params.to_owned()))
      (name, Fn(params, parse_body(body)))
    }
    _ =>
      raise SurfaceError("declaration target must be a symbol or function head")
  }
}

///|
fn parse_rec_decl_name_and_body(
  target : SExpr,
  body : ArrayView[SExpr],
) -> (String, Array[String], SurfaceExpr) raise SmlError {
  match target {
    List([Atom(Symbol(name)), .. params]) => {
      let params = parse_params(List(params.to_owned()))
      (name, params, parse_body(body))
    }
    _ => raise SurfaceError("letrec declaration target must be a function head")
  }
}

///|
fn parse_binding(item : SExpr) -> (String, SurfaceExpr) raise SmlError {
  match item {
    List(pair) if pair is [target, .. body] =>
      parse_decl_name_and_value(target, body)
    _ => raise SurfaceError("binding must have shape (name expr)")
  }
}

///|
fn parse_bindings(expr : SExpr) -> Array[(String, SurfaceExpr)] raise SmlError {
  match expr {
    List(items) => items.map(parse_binding)
    _ => raise SurfaceError("let bindings must be a list")
  }
}

///|
fn parse_rec_binding(
  item : SExpr,
) -> (String, Array[String], SurfaceExpr) raise SmlError {
  match item {
    List(pair) if pair is [target, .. body] =>
      parse_rec_decl_name_and_body(target, body)
    _ => raise SurfaceError("binding must have shape ((name args...) body...)")
  }
}

///|
fn parse_rec_bindings(
  expr : SExpr,
) -> Array[(String, Array[String], SurfaceExpr)] raise SmlError {
  match expr {
    List(items) => items.map(parse_rec_binding)
    _ => raise SurfaceError("letrec bindings must be a list")
  }
}

///|
fn parse_special_form(
  head : String,
  tail : ArrayView[SExpr],
) -> SurfaceExpr raise SmlError {
  match head {
    "if" => {
      guard tail.length() == 3 else {
        raise SurfaceError("if expects 3 arguments")
      }
      If(parse_subexpr(tail[0]), parse_subexpr(tail[1]), parse_subexpr(tail[2]))
    }
    "fn" => {
      guard tail.length() >= 1 else {
        raise SurfaceError("fn expects parameters")
      }
      Fn(parse_params(tail[0]), parse_body(tail[1:]))
    }
    "let" | "let&" | "letrec" | "letrec&" =>
      raise SurfaceError(
        "declarations are only allowed in a declaration sequence",
      )
    "do" => Fn([], parse_body(tail))
    "begin" => parse_body(tail)
    _ => Call(Var(head), tail.map(parse_subexpr))
  }
}

///|
fn parse_surface_expr_raw(expr : SExpr) -> SurfaceExpr raise SmlError {
  match expr {
    Atom(Int(value)) => Int(value)
    Atom(Bool(value)) => Bool(value)
    Atom(String(value)) => String(value)
    Atom(Symbol(name)) => Var(name)
    List(items) =>
      match items {
        [] => raise SurfaceError("empty list is not a valid expression")
        [Atom(Symbol(head)), .. tail] => parse_special_form(head, tail)
        [func, .. args] => Call(parse_subexpr(func), args.map(parse_subexpr))
      }
  }
}

///|
fn is_bare_placeholder(expr : SurfaceExpr) -> Bool {
  expr is Var("_")
}

///|
fn replace_bare_placeholder(expr : SurfaceExpr) -> SurfaceExpr {
  if is_bare_placeholder(expr) {
    Var("__arg")
  } else {
    expr
  }
}

///|
fn wrap_if_placeholder(
  cond : SurfaceExpr,
  then_branch : SurfaceExpr,
  else_branch : SurfaceExpr,
) -> SurfaceExpr {
  Fn(
    ["__arg"],
    SurfaceExpr::If(
      replace_bare_placeholder(cond),
      replace_bare_placeholder(then_branch),
      replace_bare_placeholder(else_branch),
    ),
  )
}

///|
fn wrap_call_placeholder(
  func : SurfaceExpr,
  args : ArrayView[SurfaceExpr],
) -> SurfaceExpr {
  Fn(
    ["__arg"],
    SurfaceExpr::Call(
      replace_bare_placeholder(func),
      args.map(replace_bare_placeholder),
    ),
  )
}

///|
fn expand_placeholder_expr(expr : SurfaceExpr) -> SurfaceExpr raise SmlError {
  match expr {
    If(cond, then_branch, else_branch) => {
      let cond = expand_placeholder_expr(cond)
      let then_branch = expand_placeholder_expr(then_branch)
      let else_branch = expand_placeholder_expr(else_branch)
      if is_bare_placeholder(cond) ||
        is_bare_placeholder(then_branch) ||
        is_bare_placeholder(else_branch) {
        wrap_if_placeholder(cond, then_branch, else_branch)
      } else {
        SurfaceExpr::If(cond, then_branch, else_branch)
      }
    }
    Call(func, args) => {
      let func = expand_placeholder_expr(func)
      let args = args.map(arg => expand_placeholder_expr(arg))
      if is_bare_placeholder(func) || args.any(is_bare_placeholder) {
        wrap_call_placeholder(func, args)
      } else {
        SurfaceExpr::Call(func, args)
      }
    }
    _ => expr
  }
}

///|
fn parse_subexpr(expr : SExpr) -> SurfaceExpr raise SmlError {
  expr |> parse_surface_expr_raw |> expand_placeholder_expr
}

///|
pub fn parse_surface_expr(expr : SExpr) -> SurfaceExpr raise SmlError {
  match parse_subexpr(expr) {
    Var("_") =>
      raise SurfaceError(
        "placeholder \"_\" must appear inside a compound expression",
      )
    expr => expr
  }
}

///|
fn parse_decl(expr : SExpr) -> SurfaceDecl? raise SmlError {
  match expr {
    List([Atom(Symbol("let")), target, .. tail]) => {
      let (name, value) = parse_decl_name_and_value(target, tail)
      Some(SurfaceDecl::Let(name, value))
    }
    List([Atom(Symbol("let&")), .. bindings]) if bindings.length() > 0 =>
      Some(SurfaceDecl::LetAnd(parse_bindings(List(bindings.to_owned()))))
    List([Atom(Symbol("letrec")), target, .. tail]) => {
      let (name, params, body) = parse_rec_decl_name_and_body(target, tail)
      Some(SurfaceDecl::LetRec(name, params, body))
    }
    List([Atom(Symbol("letrec&")), .. bindings]) if bindings.length() > 0 =>
      Some(
        SurfaceDecl::LetRecAnd(parse_rec_bindings(List(bindings.to_owned()))),
      )
    _ => None
  }
}

///|
fn parse_stmt(expr : SExpr) -> SurfaceStmt raise SmlError {
  match parse_decl(expr) {
    Some(decl) => SurfaceStmt::Decl(decl)
    None => SurfaceStmt::Expr(parse_surface_expr(expr))
  }
}

///|
fn parse_body(forms : ArrayView[SExpr]) -> SurfaceExpr raise SmlError {
  match forms {
    [] => Block([])
    [form] =>
      match parse_decl(form) {
        Some(decl) => Block([Decl(decl)])
        None => parse_surface_expr(form)
      }
    _ => Block(forms.map(parse_stmt))
  }
}

///|
pub fn parse_surface(source : StringView) -> SurfaceExpr raise SmlError {
  parse_body(parse_sexps(source))
}

///|
fn desugar_expr(expr : SurfaceExpr) -> CoreExpr {
  match expr {
    Int(value) => CoreExpr::Int(value)
    Bool(value) => CoreExpr::Bool(value)
    String(value) => CoreExpr::String(value)
    Var(name) => CoreExpr::Var(name)
    If(cond, then_branch, else_branch) =>
      CoreExpr::If(
        desugar_expr(cond),
        desugar_expr(then_branch),
        desugar_expr(else_branch),
      )
    Block(stmts) => desugar_block(stmts)
    Fn(params, body) => CoreExpr::Fn(params, desugar_expr(body))
    Call(func, args) =>
      CoreExpr::Call(desugar_expr(func), args.map(desugar_expr))
  }
}

///|
fn desugar_decl_to_let(decl : SurfaceDecl, body : CoreExpr) -> CoreExpr {
  match decl {
    SurfaceDecl::Let(name, value) => {
      let binding = [(name, desugar_expr(value))]
      CoreExpr::Let(binding, body)
    }
    SurfaceDecl::LetAnd(bindings) =>
      CoreExpr::Let(
        bindings.map(binding => (binding.0, desugar_expr(binding.1))),
        body,
      )
    SurfaceDecl::LetRec(name, params, value) =>
      CoreExpr::LetRec([(name, params, desugar_expr(value))], body)
    SurfaceDecl::LetRecAnd(bindings) =>
      CoreExpr::LetRec(
        bindings.map(binding => (binding.0, binding.1, desugar_expr(binding.2))),
        body,
      )
  }
}

///|
fn desugar_block(stmts : ArrayView[SurfaceStmt]) -> CoreExpr {
  guard stmts.length() > 0 else { return CoreExpr::Unit }
  let mut result = match stmts[stmts.length() - 1] {
    SurfaceStmt::Decl(decl) => desugar_decl_to_let(decl, CoreExpr::Unit)
    SurfaceStmt::Expr(expr) => desugar_expr(expr)
  }
  guard stmts.length() > 1 else { return result }
  for i = stmts.length() - 2; i >= 0; i = i - 1 {
    match stmts[i] {
      SurfaceStmt::Decl(decl) => result = desugar_decl_to_let(decl, result)
      SurfaceStmt::Expr(expr) => {
        let binding = [("_", desugar_expr(expr))]
        result = CoreExpr::Let(binding, result)
      }
    }
  }
  result
}

///|
pub fn desugar(expr : SurfaceExpr) -> CoreExpr {
  desugar_expr(expr)
}

///|
pub fn lower(source : StringView) -> CoreExpr raise SmlError {
  source |> parse_surface |> desugar
}

///|
fn env_empty() -> Env {
  @sorted_map.new()
}

///|
fn env_extend(
  parent : Env,
  bindings_to_add : ArrayView[(String, Value)],
) -> Env {
  bindings_to_add.fold(init=parent, (bindings, binding) => {
    if binding.0 == "_" {
      bindings
    } else {
      bindings.add(binding.0, binding.1)
    }
  })
}

///|
fn eval_let_bindings(
  bindings : ArrayView[(String, CoreExpr)],
  env : Env,
) -> Array[(String, Value)] raise SmlError {
  bindings.map(binding => (binding.0, eval_core(binding.1, env~)))
}

///|
fn env_lookup(env : Env, name : String) -> Value raise SmlError {
  match env.get(name) {
    Some(value) => value
    None => raise RuntimeError("unbound variable: \{name}")
  }
}

///|
fn base_env() -> Env {
  [
    "+", "++", "-", "*", "/", "=", "<", ">", "<=", ">=", "not", "say", "ref", "!",
    ":=", "%=",
  ].fold(init=env_empty(), (env, name) => env.add(name, Builtin(name)))
}

///|
fn expect_int(value : Value) -> Int raise SmlError {
  match value {
    Int(number) => number
    _ => raise RuntimeError("expected integer")
  }
}

///|
fn expect_bool(value : Value) -> Bool raise SmlError {
  match value {
    Bool(flag) => flag
    _ => raise RuntimeError("expected boolean")
  }
}

///|
fn expect_exact_arity(
  name : String,
  args : ArrayView[Value],
  expected : Int,
) -> Unit raise SmlError {
  guard args.length() == expected else {
    raise RuntimeError(
      "builtin \{name} expects \{expected} arguments, got \{args.length()}",
    )
  }
}

///|
fn value_eq(left : Value, right : Value) -> Bool {
  match (left, right) {
    (Int(a), Int(b)) => a == b
    (Bool(a), Bool(b)) => a == b
    (String(a), String(b)) => a == b
    (Unit, Unit) => true
    (Builtin(a), Builtin(b)) => a == b
    _ => false
  }
}

///|
fn value_to_say_string(value : Value) -> String {
  match value {
    String(text) => text
    _ => value.to_string()
  }
}

///|
fn say_values(args : ArrayView[Value]) -> Unit {
  println(args.map(value_to_say_string).join(" "))
}

///|
fn add_int_values(args : ArrayView[Value]) -> Value raise SmlError {
  Int(args.fold(init=0, (total, arg) => total + expect_int(arg)))
}

///|
fn sub_int_values(args : ArrayView[Value]) -> Value raise SmlError {
  match args {
    [] => raise RuntimeError("builtin - expects at least 1 argument")
    [first] => Int(-expect_int(first))
    [first, .. rest] =>
      Int(
        rest.fold(init=expect_int(first), (total, arg) => {
          total - expect_int(arg)
        }),
      )
  }
}

///|
fn mul_int_values(args : ArrayView[Value]) -> Value raise SmlError {
  Int(args.fold(init=1, (total, arg) => total * expect_int(arg)))
}

///|
fn div_int_values(args : ArrayView[Value]) -> Value raise SmlError {
  match args {
    [] | [_] => raise RuntimeError("builtin / expects at least 2 arguments")
    [first, .. rest] =>
      Int(
        rest.fold(init=expect_int(first), (total, arg) => {
          total / expect_int(arg)
        }),
      )
  }
}

///|
fn concat_values(args : ArrayView[Value]) -> Value {
  String(args.map(value_to_say_string).join(""))
}

///|
fn make_ref(args : ArrayView[Value]) -> Value raise SmlError {
  expect_exact_arity("ref", args, 1)
  Ref(value=args[0])
}

///|
fn deref_value(args : ArrayView[Value]) -> Value raise SmlError {
  expect_exact_arity("!", args, 1)
  match args[0] {
    Ref(value~) => value
    _ => raise RuntimeError("expected ref")
  }
}

///|
fn assign_ref(args : ArrayView[Value]) -> Value raise SmlError {
  expect_exact_arity(":=", args, 2)
  match args[0] {
    Ref(_) as cell => {
      cell.value = args[1]
      Unit
    }
    _ => raise RuntimeError("expected ref")
  }
}

///|
fn update_ref(args : ArrayView[Value]) -> Value raise SmlError {
  expect_exact_arity("%=", args, 2)
  match args[0] {
    Ref(_) as cell => {
      cell.value = apply(args[1], [cell.value])
      Unit
    }
    _ => raise RuntimeError("expected ref")
  }
}

///|
fn eval_letrec_bindings(
  bindings : ArrayView[(String, Array[String], CoreExpr)],
  env : Env,
) -> Env {
  let evaluated = bindings.map(binding => {
    (binding.0, Closure({ params: binding.1, body: binding.2, env }))
  })
  let rec_env = env_extend(env, evaluated)
  for binding in evaluated {
    match binding.1 {
      Closure(closure) => closure.env = rec_env
      _ => abort("unreachable")
    }
  }
  rec_env
}

///|
fn apply_builtin(
  name : String,
  args : ArrayView[Value],
) -> Value raise SmlError {
  match name {
    "+" => add_int_values(args)
    "++" => concat_values(args)
    "ref" => make_ref(args)
    "!" => deref_value(args)
    ":=" => assign_ref(args)
    "%=" => update_ref(args)
    "-" => sub_int_values(args)
    "*" => mul_int_values(args)
    "/" => div_int_values(args)
    "=" => {
      expect_exact_arity("=", args, 2)
      Bool(value_eq(args[0], args[1]))
    }
    "<" => {
      expect_exact_arity("<", args, 2)
      Bool(expect_int(args[0]) < expect_int(args[1]))
    }
    ">" => {
      expect_exact_arity(">", args, 2)
      Bool(expect_int(args[0]) > expect_int(args[1]))
    }
    "<=" => {
      expect_exact_arity("<=", args, 2)
      Bool(expect_int(args[0]) <= expect_int(args[1]))
    }
    ">=" => {
      expect_exact_arity(">=", args, 2)
      Bool(expect_int(args[0]) >= expect_int(args[1]))
    }
    "not" => {
      expect_exact_arity("not", args, 1)
      Bool(!expect_bool(args[0]))
    }
    "say" => {
      say_values(args)
      Unit
    }
    _ => raise RuntimeError("unknown builtin: \{name}")
  }
}

///|
fn apply(func : Value, args : ArrayView[Value]) -> Value raise SmlError {
  match func {
    Builtin(name) => apply_builtin(name, args)
    Closure(closure) => {
      guard closure.params.length() == args.length() else {
        raise RuntimeError(
          "function expects \{closure.params.length()} arguments, got \{args.length()}",
        )
      }
      let bindings = [
        for i, param in closure.params if param != "_" => (param, args[i])
      ]
      eval_core(closure.body, env=env_extend(closure.env, bindings))
    }
    _ => raise RuntimeError("attempted to call a non-function value")
  }
}

///|
pub fn eval_core(
  expr : CoreExpr,
  env? : Env = base_env(),
) -> Value raise SmlError {
  match expr {
    Int(value) => Value::Int(value)
    Bool(value) => Value::Bool(value)
    String(value) => Value::String(value)
    Unit => Value::Unit
    Var(name) => env_lookup(env, name)
    If(cond, then_branch, else_branch) =>
      if expect_bool(eval_core(cond, env~)) {
        eval_core(then_branch, env~)
      } else {
        eval_core(else_branch, env~)
      }
    Let(bindings, body) => {
      let evaluated = eval_let_bindings(bindings, env)
      eval_core(body, env=env_extend(env, evaluated))
    }
    LetRec(bindings, body) => {
      let rec_env = eval_letrec_bindings(bindings, env)
      eval_core(body, env=rec_env)
    }
    Fn(params, body) => Closure({ params, body, env })
    Call(func, args) => {
      let fun_value = eval_core(func, env~)
      let arg_values = args.map(arg => eval_core(arg, env~))
      apply(fun_value, arg_values)
    }
  }
}

///|
pub fn run(source : StringView) -> Value raise SmlError {
  source |> lower |> eval_core
}

///|
pub fn run_to_string(source : StringView) -> String raise SmlError {
  run(source).to_string()
}
