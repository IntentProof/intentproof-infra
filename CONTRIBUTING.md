# Contributing to intentproof-infra

Thanks for your interest in IntentProof.

## Issues welcome

Please report bugs and documentation gaps via
[GitHub Issues](https://github.com/IntentProof/intentproof-infra/issues).

We do **not** accept unsolicited pull requests from outside the
maintainer team. If you are a customer or partner with a change that
must land upstream, contact IntentProof, Inc. before opening a PR.

## Maintainer workflow

Open pull requests from topic branches on this repository
(`git push -u origin <branch>`). Maintainer commits use DCO
`Signed-off-by:` trailers where CI requires them.

## Release signing callers

Released infrastructure artifacts must use the canonical release signing
workflow in `IntentProof/intentproof-tools`:

```yaml
jobs:
  sign-artifacts:
    uses: IntentProof/intentproof-tools/.github/workflows/release-build-sign.yml@main
    permissions:
      contents: write
      id-token: write
      packages: write
    with:
      artifact_kind: generic
      subject_name: intentproof-infra-reference
      release_version: ${{ github.ref_name }}
      release_ref: ${{ github.ref }}
      artifact_paths: dist/intentproof-infra-reference.tar.gz
```

Caller workflows must grant `id-token: write`; keyless Sigstore signing fails
closed without GitHub OIDC. Use `attest_to_rekor: false` only for dry-run
pre-release checks. Production release workflows must publish to Rekor.

Use `artifact_kind: generic` for reference deployment bundles, generated
manifests, or other non-container release files. Use `artifact_kind: container`
only with digest-bound GHCR references such as
`ghcr.io/intentproof/<image>@sha256:<digest>`. Do not sign mutable tags.

If artifacts are built in a separate job, upload them with
`actions/upload-artifact` and pass both `artifact_download_name` and
`artifact_download_path` to the reusable workflow. The `artifact_paths` values
must match the paths after download.

Dry-run new callers before release by invoking the `release signing dry run`
workflow in `IntentProof/intentproof-tools`. It exercises binary and generated
container signing with Rekor upload disabled.

## License

By contributing as a maintainer, you agree your commits are licensed
under the Apache License 2.0 (see `LICENSE`).
