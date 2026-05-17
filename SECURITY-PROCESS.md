# IntentProof Security Release Process

This process governs intake, triage, embargo, patching, disclosure, customer
notification, and post-mortem handling for vulnerabilities in IntentProof
repositories and released artifacts.

## Intake

Security reports enter through `security@intentproof.io` or private GitHub
Security Advisories in the affected repository. Public GitHub Issues are only
appropriate after an issue is already public and no sensitive exploitation
detail remains.

The intake owner records:

- Reporter name and contact.
- Affected repository, package, binary, image, endpoint, or release channel.
- First-seen time in UTC.
- Public/private status and any known third-party recipients.
- Reproduction material, impact summary, and suspected severity.

The public OpenPGP key for encrypted reports is published at
`keys/intentproof-security.asc` after the offline key ceremony described in
[`keys/README.md`](keys/README.md). Until that key is published, use a private
GitHub Security Advisory or send an initial unclassified message to arrange a
secure channel.

## Severity Classification

Use CVSS v3.1 base score as the entry point, then apply the IntentProof-specific
override. The override escalates regardless of the CVSS score.

| Tier | CVSS v3.1 entry | IntentProof override | Response SLA |
|------|------------------|----------------------|--------------|
| Critical | 9.0-10.0 | Forging a valid `VerificationRun` or bundle without the legitimate signing key; RCE in `intentproof-verify` or `intentproof-core`; tenant cross-read of events, flows, or bundles | 24 hour coordinated emergency patch across all affected channels |
| High | 7.0-8.9 | Auth bypass; signature-verification bypass without full forgery; policy DSL sandbox escape; KMS or Secrets Manager misuse that exposes secrets | 7 day patched release across all affected channels |
| Medium | 4.0-6.9 | DoS without data isolation breach; non-secret information disclosure; dependency vulnerability with no demonstrated exploit path against IntentProof | Next scheduled minor release, no later than 30 days |
| Low | 0.1-3.9 | Hardening opportunity or defense-in-depth improvement with no known exploit | Next scheduled release; no separate notification |

When evidence is incomplete, classify at the highest credible tier until
analysis proves a lower tier.

## Triage

Within one business day of intake, the triage owner:

1. Confirms receipt to the reporter.
2. Assigns a tracking identifier.
3. Identifies affected repositories and release channels.
4. Sets an initial severity tier and SLA deadline.
5. Decides whether an embargo is required.

Critical and High reports must have an engineering owner, reviewer, and release
owner assigned before remediation work begins.

## Embargo Handling

Use embargo for any report whose public disclosure would materially increase
risk before a patch is available. Embargoed work happens in private security
advisory branches or private forks. Do not reference sensitive exploit details
in public commits, pull request titles, CI logs, release notes, or issue
comments before disclosure.

The embargo record includes:

- Participants and organizations with access.
- Disclosure deadline or coordinated publication date.
- Affected versions and candidate fixed versions.
- Communication log with reporter and affected customers.

## Patch Release Procedure

For confirmed Critical and High issues:

1. Land the smallest reviewed fix in each affected repository.
2. Run the normal quality gates plus targeted regression checks.
3. Build patched artifacts through the signed release workflows.
4. Verify Cosign signatures, SBOM attestations, and provenance before publish.
5. Publish patched artifacts to every affected channel.
6. Prepare customer notification and advisory text.
7. Coordinate public disclosure with the reporter when applicable.

Release channels include GitHub Releases, GHCR, npm, PyPI, Homebrew, apt, RPM,
and any customer-specific mirror that received the affected artifact.

## Customer Notification

Use [`docs/security-notification-template.md`](docs/security-notification-template.md)
for confirmed issues requiring customer action. Notifications must include:

- Severity and affected versions.
- Exploitability and impact in plain language.
- Fixed versions and verification instructions.
- Required customer action and deadline.
- Credits and disclosure timeline when safe to publish.

Low severity dry runs may render the template without sending it.

## Post-Mortem

Use [`docs/security-postmortem-template.md`](docs/security-postmortem-template.md)
for Critical, High, and customer-visible Medium issues. The post-mortem must
identify detection gaps, prevention gaps, release process gaps, and follow-up
owners.

## Dry-Run Evidence

Dry-run the process periodically with a fabricated low-severity issue. Store
evidence in `docs/` and include:

- Intake record.
- Triage classification.
- Embargo decision.
- Fix PR or simulated fix plan.
- Patched release decision.
- Rendered notification template.
- Post-mortem template.

The first dry-run record lives in
[`docs/security-dry-run-low-severity.md`](docs/security-dry-run-low-severity.md).
