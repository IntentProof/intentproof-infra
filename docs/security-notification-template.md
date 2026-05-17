# Security Notification Template

Subject: IntentProof security advisory: `<identifier>` (`<severity>`)

## Summary

IntentProof has fixed `<brief vulnerability summary>`.

Severity: `<Critical | High | Medium | Low>`

Affected versions: `<versions or artifacts>`

Fixed versions: `<versions or artifacts>`

## Impact

`<Plain-language impact statement. Include whether data isolation, signature
verification, artifact integrity, or availability is affected.>`

## Required Action

`<Upgrade, rotate credentials, rebuild from fixed image, verify signatures, or
no action required.>`

## Verification

Customers can verify fixed artifacts with the published Cosign identity:

```bash
cosign verify-blob \
  --certificate-identity-regexp 'https://github.com/IntentProof/' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  --bundle <artifact>.sigstore.json \
  --signature <artifact>.sig \
  <artifact>
```

## Timeline

- `<timestamp>`: Report received.
- `<timestamp>`: Severity confirmed.
- `<timestamp>`: Patch released.
- `<timestamp>`: Advisory published.

## Credits

Reported by `<reporter or "IntentProof internal testing">`.
