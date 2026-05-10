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
  List(ReadOnlyArray[SExpr])
} derive(Eq, Debug)

///|
pub enum SurfaceExpr {
  Int(Int)
  Bool(Bool)
  String(String)
  Var(String)
  If(SurfaceExpr, SurfaceExpr, SurfaceExpr)
  Block(ReadOnlyArray[SurfaceStmt])
  Fn(ReadOnlyArray[String], SurfaceExpr)
  Call(SurfaceExpr, ReadOnlyArray[SurfaceExpr])
} derive(Eq, Debug)

///|
pub enum SurfaceDecl {
  Let(String, SurfaceExpr)
  LetAnd(ReadOnlyArray[(String, SurfaceExpr)])
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
  Let(ReadOnlyArray[(String, CoreExpr)], CoreExpr)
  Fn(ReadOnlyArray[String], CoreExpr)
  Call(CoreExpr, ReadOnlyArray[CoreExpr])
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
  params : ReadOnlyArray[String]
  body : CoreExpr
  env : Env
}

///|
pub enum Value {
  Int(Int)
  Bool(Bool)
  String(String)
  Unit
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
fn parse_atom_token(token : String) -> SAtom raise SmlError {
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
        Symbol(token)
      }
  }
}

///|
fn is_int_token(token : String) -> Bool {
  let view = token[:]
  match view {
    [] => false
    ['-', .. tail] => has_only_digits(tail)
    _ => has_only_digits(view)
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
      [')', .. tail] => break (tail, List(ReadOnlyArray::from_array(items)))
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
pub fn parse_sexp(source : String) -> SExpr raise SmlError {
  let (rest, expr) = parse_sexp_inner(source[:])
  guard skip_ws(rest) is [] else {
    raise ParseError("unexpected trailing input")
  }
  expr
}

///|
fn parse_sexps(source : String) -> ReadOnlyArray[SExpr] raise SmlError {
  let exprs = []
  for rest = skip_ws(source[:]) {
    match rest {
      [] => break ReadOnlyArray::from_array(exprs)
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
fn parse_params(expr : SExpr) -> ReadOnlyArray[String] raise SmlError {
  match expr {
    List(items) => {
      let params = []
      for item in items {
        params.push(expect_symbol_atom(item))
      }
      ReadOnlyArray::from_array(params)
    }
    _ => raise SurfaceError("function parameter list must be a list")
  }
}

///|
fn parse_bindings(
  expr : SExpr,
) -> ReadOnlyArray[(String, SurfaceExpr)] raise SmlError {
  match expr {
    List(items) => {
      let bindings = []
      for item in items {
        match item {
          List(pair) if pair.length() >= 2 => {
            let name = expect_symbol_atom(pair[0])
            let value = parse_body(pair[1:])
            bindings.push((name, value))
          }
          _ => raise SurfaceError("binding must have shape (name expr)")
        }
      }
      ReadOnlyArray::from_array(bindings)
    }
    _ => raise SurfaceError("let bindings must be a list")
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
      If(
        parse_surface_expr(tail[0]),
        parse_surface_expr(tail[1]),
        parse_surface_expr(tail[2]),
      )
    }
    "fn" => {
      guard tail.length() >= 2 else {
        raise SurfaceError("fn expects parameters and a body")
      }
      Fn(parse_params(tail[0]), parse_body(tail[1:]))
    }
    "let" =>
      raise SurfaceError(
        "let declarations are only allowed in a declaration sequence",
      )
    "do" => {
      guard tail.length() > 0 else {
        raise SurfaceError("do expects at least one expression")
      }
      parse_body(tail)
    }
    _ =>
      Call(Var(head), ReadOnlyArray::from_array(tail.map(parse_surface_expr)))
  }
}

///|
pub fn parse_surface_expr(expr : SExpr) -> SurfaceExpr raise SmlError {
  match expr {
    Atom(Int(value)) => Int(value)
    Atom(Bool(value)) => Bool(value)
    Atom(String(value)) => String(value)
    Atom(Symbol(name)) => Var(name)
    List(items) =>
      match items {
        [] => raise SurfaceError("empty list is not a valid expression")
        [Atom(Symbol(head)), .. tail] => parse_special_form(head, tail)
        [func, .. args] =>
          Call(
            parse_surface_expr(func),
            ReadOnlyArray::from_array(args.map(parse_surface_expr)),
          )
      }
  }
}

///|
fn parse_decl(expr : SExpr) -> SurfaceDecl? raise SmlError {
  match expr {
    List([Atom(Symbol("let")), Atom(Symbol(name)), .. tail]) if tail.length() >
      0 => Some(SurfaceDecl::Let(name, parse_body(tail)))
    List([Atom(Symbol("let&")), .. bindings]) if bindings.length() > 0 =>
      Some(
        SurfaceDecl::LetAnd(
          parse_bindings(List(ReadOnlyArray::from_array(bindings))),
        ),
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
fn parse_block(forms : ReadOnlyArray[SExpr]) -> SurfaceExpr raise SmlError {
  guard forms.length() > 0 else {
    raise SurfaceError("expected at least one form")
  }
  if forms.length() == 1 {
    match parse_decl(forms[0]) {
      Some(decl) => Block([Decl(decl)])
      None => parse_surface_expr(forms[0])
    }
  } else {
    Block(forms.map(parse_stmt))
  }
}

///|
fn parse_body(forms : ArrayView[SExpr]) -> SurfaceExpr raise SmlError {
  parse_block(ReadOnlyArray::from_array(forms.to_owned()))
}

///|
pub fn parse_surface(source : String) -> SurfaceExpr raise SmlError {
  parse_block(parse_sexps(source))
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
      CoreExpr::Let(ReadOnlyArray::from_array(binding), body)
    }
    SurfaceDecl::LetAnd(bindings) =>
      CoreExpr::Let(
        bindings.map(binding => (binding.0, desugar_expr(binding.1))),
        body,
      )
  }
}

///|
fn desugar_block(stmts : ReadOnlyArray[SurfaceStmt]) -> CoreExpr {
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
        result = CoreExpr::Let(ReadOnlyArray::from_array(binding), result)
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
pub fn lower(source : String) -> CoreExpr raise SmlError {
  source |> parse_surface |> desugar
}

///|
fn env_empty() -> Env {
  @sorted_map.new()
}

///|
fn env_extend(
  parent : Env,
  bindings_to_add : ReadOnlyArray[(String, Value)],
) -> Env {
  let mut bindings = parent
  for binding in bindings_to_add {
    bindings = bindings.add(binding.0, binding.1)
  }
  bindings
}

///|
fn eval_let_bindings(
  bindings : ReadOnlyArray[(String, CoreExpr)],
  env : Env,
) -> ReadOnlyArray[(String, Value)] raise SmlError {
  let evaluated = []
  for binding in bindings {
    evaluated.push((binding.0, eval_core(binding.1, env~)))
  }
  ReadOnlyArray::from_array(evaluated)
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
  let mut env = env_empty()
  for name in ["+", "-", "*", "/", "=", "<", ">", "<=", ">=", "not", "println"] {
    env = env.add(name, Builtin(name))
  }
  env
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
  args : ReadOnlyArray[Value],
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
fn apply_builtin(
  name : String,
  args : ReadOnlyArray[Value],
) -> Value raise SmlError {
  match name {
    "+" => {
      let mut total = 0
      for arg in args {
        total = total + expect_int(arg)
      }
      Int(total)
    }
    "-" => {
      guard args.length() > 0 else {
        raise RuntimeError("builtin - expects at least 1 argument")
      }
      let first = expect_int(args[0])
      if args.length() == 1 {
        Int(-first)
      } else {
        let mut total = first
        for i = 1; i < args.length(); i = i + 1 {
          total = total - expect_int(args[i])
        }
        Int(total)
      }
    }
    "*" => {
      let mut total = 1
      for arg in args {
        total = total * expect_int(arg)
      }
      Int(total)
    }
    "/" => {
      guard args.length() >= 2 else {
        raise RuntimeError("builtin / expects at least 2 arguments")
      }
      let mut total = expect_int(args[0])
      for i = 1; i < args.length(); i = i + 1 {
        total = total / expect_int(args[i])
      }
      Int(total)
    }
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
    "println" => {
      expect_exact_arity("println", args, 1)
      println(args[0].to_string())
      Unit
    }
    _ => raise RuntimeError("unknown builtin: \{name}")
  }
}

///|
fn apply(func : Value, args : ReadOnlyArray[Value]) -> Value raise SmlError {
  match func {
    Builtin(name) => apply_builtin(name, args)
    Closure(closure) => {
      guard closure.params.length() == args.length() else {
        raise RuntimeError(
          "function expects \{closure.params.length()} arguments, got \{args.length()}",
        )
      }
      let bindings = [
        for i = 0; i < closure.params.length(); i = i + 1 => {
          (closure.params[i], args[i])
        }
      ]
      eval_core(
        closure.body,
        env=env_extend(closure.env, ReadOnlyArray::from_array(bindings)),
      )
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
    Fn(params, body) => Closure({ params, body, env })
    Call(func, args) => {
      let fun_value = eval_core(func, env~)
      let arg_values = args.map(arg => eval_core(arg, env~))
      apply(fun_value, arg_values)
    }
  }
}

///|
pub fn run(source : String) -> Value raise SmlError {
  source |> lower |> eval_core
}

///|
pub fn run_to_string(source : String) -> String raise SmlError {
  run(source).to_string()
}
