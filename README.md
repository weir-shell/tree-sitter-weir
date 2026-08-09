# tree-sitter-weir

A tree-sitter grammar for [weir](https://github.com/weir-shell/weir) —
**a renderer, not a second parser**. The one truth for what weir
accepts is `weir check`'s pipeline (the main repo's SEMANTICS.md);
this grammar's only job is better-than-grey highlighting in
tree-sitter consumers (Helix, Zed, code forges). It over-accepts
freely, does not replicate the assembler's logical-line
reconstruction (a continuation line may highlight as a fresh
statement), and must never be cited as the language definition.

Generated `src/` is committed (**ABI 14** — the CLI churns generated
boilerplate across versions but the last regenerations held ABI 14;
a consumer pinning a rev gets what that rev says) so consumers
(Helix `--grammar build`, Zed) need no Node.js.

**Tracked weir version**: the ref in [`TRACKED_WEIR_REF`](TRACKED_WEIR_REF).
CI checks this grammar against that ref's generated
`editors/grammar-manifest.json` (keywords, `within` kinds, adapter
names) and parses that ref's `.weir` corpus with the zero-ERROR bar.
Bumping the ref is the deliberate act of tracking a newer language.

This repo split out of the main tree on 2026-08-09 with fresh
history; the grammar's prior evolution lives in
[weir-shell/weir](https://github.com/weir-shell/weir) under
`editors/tree-sitter-weir` (removed at the split).

## Helix

```toml
# languages.toml
[[grammar]]
name = "weir"
source = { git = "https://github.com/weir-shell/tree-sitter-weir" }
```

then `hx --grammar fetch && hx --grammar build`, and copy
`queries/highlights.scm` to `~/.config/helix/runtime/queries/weir/`.
Add `grammar = "weir"` (implied by the language name) to the
`[[language]]` block from the main repo's `docs/editors.md`.

## Regenerating

`tree-sitter generate` (needs the tree-sitter CLI and Node). The
corpus acceptance: `tree-sitter parse` over every `.weir` in the
tracked weir ref's `examples/` and `tools/` must produce zero ERROR
nodes (one recorded exception below).

## Known nits

- `$"... {{literal braces}} ..."` — the interp rules mis-lex a
  `{{`-escape adjacent to a closing quote (ONE ERROR node,
  examples/showcase.weir, present since before the block-scalars
  session; verified pre-existing). The corpus-acceptance rule
  tolerates exactly this one until a coloring session takes it; the
  fix likely lives in the `interp_text`/`interp_escape` token
  ordering.
