///|
fn input_options() -> Array[@argparse.OptionArg] {
  [
    @argparse.OptionArg(
      "expr",
      short='e',
      about="Read the program directly from the command line.",
    ),
  ]
}

///|
fn input_positionals() -> Array[@argparse.PositionArg] {
  [@argparse.PositionArg("path", about="Read the program from a source file.")]
}

///|
fn input_groups() -> Array[@argparse.ArgGroup] {
  [
    @argparse.ArgGroup("input", required=true, multiple=false, args=[
      "expr", "path",
    ]),
  ]
}

///|
fn stage_command(name : String, about : String) -> @argparse.Command {
  @argparse.Command(
    name,
    about~,
    options=input_options(),
    positionals=input_positionals(),
    groups=input_groups(),
  )
}

///|
fn cli_command() -> @argparse.Command {
  @argparse.Command(
    "sml",
    about="Tools for the S-expression-based ML-like language.",
    version="0.1.0",
    subcommand_required=true,
    subcommands=[
      stage_command("run", "Evaluate a program and print the resulting value."),
      stage_command("sexp", "Parse a program and print the S-expression AST."),
      stage_command("surface", "Parse a program and print the surface AST."),
      stage_command("core", "Desugar a program and print the core AST."),
    ],
  )
}

///|
fn lookup_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) if values.length() > 0 => Some(values[0])
    _ => None
  }
}

///|
fn required_value(matches : @argparse.Matches, name : String) -> String {
  match lookup_value(matches, name) {
    Some(value) => value
    None => panic()
  }
}

///|
fn load_source(matches : @argparse.Matches) -> String raise @fs.IOError {
  match lookup_value(matches, "expr") {
    Some(expr) => expr
    None => @fs.read_file_to_string(required_value(matches, "path"))
  }
}

///|
fn render_stage(name : String, source : String) -> String raise @sml.SmlError {
  match name {
    "run" => @sml.run_to_string(source)
    "sexp" => @debug.to_string(@sml.parse_sexp(source))
    "surface" => @debug.to_string(@sml.parse_surface(source))
    "core" => @debug.to_string(@sml.lower(source))
    _ => panic()
  }
}

///|
fn main {
  try {
    let matches = cli_command().parse()
    guard matches.subcommand is Some((name, submatches)) else {
      println("internal error: missing subcommand")
    }
    let source = load_source(submatches)
    let output = render_stage(name, source)
    println(output)
  } catch {
    err => @debug.debug(err)
  }
}
