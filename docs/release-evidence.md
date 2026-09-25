# Release evidence

The local release script creates an unsigned Apple Silicon archive and SHA-256 checksum:

```sh
./scripts/release.sh
```

This is not a public release. Before distribution, the owner must provide a Developer ID signing identity, hardened-runtime review, notarization credentials/profile, Gatekeeper assessment, stapling output, quarantine installation evidence, checksum and an approved publication destination. Credentials must remain outside the repository.

Current metadata: version `0.1.0`, macOS 14+, Apple Silicon, bundle identifier `dev.rill.Rill`, Swift 6. License and public branding remain owner decisions.
