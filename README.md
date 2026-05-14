# intentproof-infra

Reference infrastructure and local dev stacks for IntentProof.

## Scope

- Local docker-compose stacks (hosted-ingest dev dependencies)
- Sanitized reference deployment material for self-hosters

Production Terraform, secrets layout, IAM, and operational infrastructure live in the private repository:

<https://github.com/IntentProof/intentproof-infra-private>

## Quick start (local)

From `docker/`:

`docker-compose -f docker-compose.hosted-dev.yml up -d`

## License

Apache License 2.0 (`LICENSE`).
