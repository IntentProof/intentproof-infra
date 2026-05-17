# Security Intake Key Rotation

This runbook governs rotation of the public OpenPGP key used for encrypted
security reports to `security@intentproof.io`.

The key is an intake-encryption key only. Release artifact signing remains
Sigstore keyless signing through GitHub Actions OIDC.

## Custody Rules

- Never commit private key material, secret key exports, revocation
  certificates, hardware-token backups, or passphrases.
- Keep the primary key offline or on a hardware token under designated
  security-owner custody.
- Keep encrypted offline backups in two controlled physical locations.
- Store backup passphrases separately in a restricted company password-manager
  vault with emergency access or two-person approval.
- Publish only `intentproof-security.asc`,
  `intentproof-security.fingerprint.json`, and public Sigstore metadata.

## Planned Rotation

Start planned rotation at least 30 days before the current key expires.

1. Generate the replacement key through the ceremony in `README.md`.
2. Export the replacement public key to `intentproof-security.asc`.
3. Generate a new `intentproof-security.fingerprint.json` manifest.
4. Create a key-transition statement signed by the outgoing key when available.
5. Commit the new public key, new fingerprint manifest, and transition
   statement.
6. Sign the new fingerprint manifest with the `sign security key fingerprint`
   workflow using `artifact_kind: generic`.
7. Keep the old public key and transition statement published during the
   overlap window.
8. Update `SECURITY.md` and `SECURITY-PROCESS.md` if contact, custody, or
   reporter guidance changes.

Use a 30 day overlap window unless the security owner records a different
window in the transition statement.

## Emergency Rotation

Use emergency rotation if any private key material, hardware token, backup
medium, or passphrase may be exposed or lost.

1. Stop using the suspected key immediately.
2. Generate a replacement key through the ceremony in `README.md`.
3. Publish the replacement public key and fingerprint manifest.
4. Publish the revocation certificate for the suspected key if revocation is
   required and available.
5. If the outgoing key is still trusted enough to sign a transition statement,
   publish that statement; otherwise document why no outgoing signature exists.
6. Update `SECURITY.md` and `SECURITY-PROCESS.md` with any temporary reporter
   instructions.
7. Notify active reporters and affected private advisory participants of the
   new fingerprint through the advisory channel.

Do not wait for the normal release train when rotating after a custody concern.

## Transition Statement

Store transition statements as
`intentproof-security-transition-YYYYMMDD.md`.

Use this template:

```markdown
# IntentProof Security Intake Key Transition

Date: YYYY-MM-DD
Outgoing fingerprint: <old fingerprint>
Incoming fingerprint: <new fingerprint>
Outgoing public key file: <old public key path or tag>
Incoming public key file: intentproof-security.asc
Overlap window: YYYY-MM-DD through YYYY-MM-DD
Reason: planned rotation | emergency rotation | custody concern | expiry

IntentProof is rotating the OpenPGP key used for encrypted security reports to
security@intentproof.io. Reporters should encrypt new reports to the incoming
key after the start of the overlap window. During the overlap window, both
fingerprints remain published for verification.
```

Sign the statement with the outgoing key when available:

```bash
gpg --armor --detach-sign intentproof-security-transition-YYYYMMDD.md
```

If the outgoing key cannot be trusted or cannot sign, include an unsigned
transition statement and document the reason in the emergency rotation record.

## Verification

Verify the published public key:

```bash
gpg --show-keys keys/intentproof-security.asc
gpg --with-colons --show-keys keys/intentproof-security.asc
```

Verify the fingerprint in the manifest matches the public key:

```bash
gpg --with-colons --show-keys keys/intentproof-security.asc |
  awk -F: '$1 == "fpr" { print $10; exit }'
```

Compare that value to `fingerprint` in
`intentproof-security.fingerprint.json`.

Verify the Sigstore metadata for the fingerprint manifest after the signing
workflow publishes it. For Rekor-backed publication, dispatch
`sign security key fingerprint` with `attest_to_rekor: true` and a SemVer tag
`release_ref`.

```bash
cosign verify-blob \
  --certificate-identity-regexp 'https://github.com/IntentProof/' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  --bundle <sigstore-bundle-file> \
  --signature <signature-file> \
  keys/intentproof-security.fingerprint.json
```

## Retirement

After the overlap window:

1. Keep the old public key and transition statement available in release
   history.
2. Remove stale references from current reporter instructions.
3. Confirm `SECURITY.md`, `SECURITY-PROCESS.md`, and this directory all point
   to the current fingerprint.
4. Record the retirement in the next security process review.
