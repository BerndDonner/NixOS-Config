# ConTeXt LMTX build tests

Both Nix derivations exercise these three documents during their builds:

- `smoke.tex`: a real PDF using the bundled fonts, `\unit` and MetaPost.
- `filter.tex`: executes an external `cp` filter on newly created temporary
  files; asserts the filter actually wrote the expected content.
- `vim.tex`: calls the external Vim highlighter on a Python code block;
  asserts Vim generated `\SYN[` tokens, not merely a PDF.

Every test runs in its own newly created working directory. A PDF alone is
insufficient evidence that the external filter actually ran successfully.

Vim is supplied as a **build-time tool**, not copied into the portable bundle.
Users who want Vim highlighting at runtime must supply Vim in `PATH` in the
execution environment (including `context-agent`). The portable engine and
bundled TeX tree remain self-contained for normal ConTeXt documents.

The patched LMTX writeability check is kept in
`../patches/filter-lmtx-writable.patch` until the filter upstream PR is merged.
Do not change `t-filter.mkiv`: its writeability check has different semantics.

These checks do not establish full typographic correctness of `\unit` or
`\digits`. Those will be tested separately after upstream fixes land.
