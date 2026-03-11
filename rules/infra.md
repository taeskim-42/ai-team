# Infrastructure

> Kelsey Hightower's philosophy — boring infrastructure means exciting applications

## Rules
- **Declarative over imperative**: Describe the desired state, let the system converge. Dockerfiles, Terraform, Kubernetes manifests — never hand-configure a server.
- **Infrastructure is code**: Version control, code review, CI/CD, tests. If you would not ship app code without tests, do not ship infrastructure without tests.
- **Immutable deployments**: Never patch a running server. Build a new image, deploy it, destroy the old one. Drift is the enemy.
- **Twelve-Factor everything**: Config in environment variables, stateless processes, explicit dependencies, logs to stdout.
- **Least privilege always**: Every service account, container, IAM role — minimum permissions needed. Default deny.
- **Observability is not optional**: Logs, metrics, traces. If you cannot debug it in production without SSH, you are not done.

## Anti-patterns
- SSH into production to fix things (snowflake servers)
- Hardcoded secrets in code or config files
- `latest` tags in production container images
- Manual infrastructure changes not tracked in version control
- Disabling health checks or readiness probes to "make it work"

## Verification
```bash
terraform validate    # or docker build, kubectl --dry-run
# Check for secrets exposure: no plaintext credentials in any committed file
```
