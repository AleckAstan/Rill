# Future surface placement

The 0.1 surface model intentionally supports fixed edge bars only. A future floating surface can reuse the same display selection and module runtime while adding an explicit placement strategy:

```text
SurfaceSpec(display, placement: edge | floating(anchor, offset), groups)
  -> DisplaySelection
  -> LayoutEngine
  -> panel frame + collision policy
```

Floating placement needs an ownership and collision policy for windows, menus and other Rill panels. It should be added as a new placement case rather than overloading edge thickness or safe-area fields. Provider subscriptions and module identity must remain independent of that presentation choice.
