# Security Intake Key Ceremony

The public security intake key is published here after an offline key ceremony.
Do not commit private key material to this repository.

## Required Outputs

- `intentproof-security.asc`: armored public OpenPGP key for
  `IntentProof Security <security@intentproof.io>`.
- `intentproof-security.fingerprint.json`: JSON manifest containing the key
  fingerprint, user ID, creation time, expiry, and rotation notes.
- Sigstore metadata for the fingerprint manifest, produced by the
  `sign security key fingerprint` workflow with `artifact_kind: generic`.

## Ceremony

1. Generate an offline 4096-bit RSA primary key on a clean workstation.
2. Add separate signing and encryption subkeys.
3. Set the user ID to `IntentProof Security <security@intentproof.io>`.
4. Set expiry to three years.
5. Keep the primary key on a hardware token or equivalent offline custody.
6. Export only the armored public key to `intentproof-security.asc`.
7. Record the fingerprint in `intentproof-security.fingerprint.json`.
8. Sign the fingerprint manifest with the `sign security key fingerprint`
   workflow.

## Rotation

Follow [`ROTATION.md`](ROTATION.md) before expiry or after any custody
concern. At a high level:

1. Generate the replacement key through the same ceremony.
2. Sign a key-transition statement with the outgoing key when available.
3. Publish both old and new fingerprints during the overlap window.
4. Update `SECURITY.md` and `SECURITY-PROCESS.md` if contact or custody
   details change.
