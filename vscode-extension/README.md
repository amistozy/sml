# VS Code extension

This directory contains a minimal VS Code extension that provides syntax
highlighting for the S-expression-based ML-like language in this repository.

## Local install

1. Open VS Code.
2. Open the Extensions view.
3. Choose `...` -> `Install from VSIX...` if you have packaged the extension,
   or use `Developer: Install Extension from Location...` and select this
   directory.

## What it highlights

- comments starting with `;`
- strings and supported escapes
- integers
- booleans
- special forms such as `if`, `fn`, `do`, `begin`, `let`, `let&`, `letrec`,
  and `letrec&`
- builtins such as `say`, `ref`, `!`, `:=`, and `%=`
- the `_` placeholder shorthand
