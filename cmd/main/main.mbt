///|
/// Entry point for the CLI or runnable program in this template.
/// Keep main focused; move logic into the library package.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let args = @env.args()
  if args.length() < 2 {
    println("usage: moon run cmd/main -- \"(<expr>)\"")
    return
  }
  let program = args[1:].join(" ")
  println(@sml.run_to_string(program)) catch {
    err => println("error: \{err}")
  }
}
