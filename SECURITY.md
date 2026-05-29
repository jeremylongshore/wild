# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest | Yes |
| < latest | Best effort |

`wild` will follow SemVer once v0.1.0 ships. Until then this gem is pre-release
and security fixes flow to `main`.

## Reporting a Vulnerability

**Please do NOT open public issues for security concerns.**

Email **security@jeremylongshore.com** with:

- Type of issue (e.g., privilege escalation through capability-gate bypass, SQL injection through introspection adapter, audit-trail tampering, prompt injection in MCP tool descriptions)
- Which `Wild::` namespace is affected (or `engine` for global)
- Full paths of related source files
- Location of the affected code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce (capability rules, access policies)
- Step-by-step instructions to reproduce
- Proof-of-concept or exploit code (if possible)
- Impact assessment

### Response Timeline

| Stage | Timeframe |
|-------|-----------|
| Acknowledgment | 24 hours |
| Initial assessment | 48 hours |
| Status update | 5 business days |
| Resolution | Depends on severity |

### Severity Levels

| Severity | CVSS | Examples | Target Resolution |
|----------|------|---------|-------------------|
| Critical | 9.0–10.0 | Capability-gate bypass, audit-trail forgery, remote code execution through MCP transport | 24 hours |
| High | 7.0–8.9 | Privilege escalation through introspection, sensitive-data exposure through telemetry collector | 7 days |
| Medium | 4.0–6.9 | Audit-event omission on rare paths, denial of service against MCP server | 30 days |
| Low | 0.1–3.9 | Information disclosure through error messages | 90 days |

## Disclosure Process

1. **Report** — You email the details to security@jeremylongshore.com
2. **Triage** — We assess severity and impact
3. **Fix** — We develop and test a patch
4. **Notify** — We inform affected users
5. **Release** — We publish the fix
6. **Post-Mortem** — We document lessons learned in `000-docs/`

## Per-namespace threat-model surface

Each namespace's threat-surface notes live in its directory's README under
`lib/wild/<namespace>/THREAT_MODEL.md`. The cross-cutting threat model and
consistency model live at the repo root in `000-docs/` once written.

## Security Best Practices

When contributing to this project:

- Never hardcode credentials or secrets
- Validate all input at MCP transport boundaries before it reaches namespace code
- Keep dependencies up to date (Dependabot is configured)
- Every `rescue` in capability-gate decision paths MUST emit a structured audit event (Armstrong F2 fix, council rev2)
- Use the shared `wildcard_corpus.yml` for matching tests across permission-analyzer and capability-gate
- Do not log sensitive payload contents from telemetry collector
- Write tests for security-critical paths — especially audit-emission liveness

## Recognition

We appreciate responsible disclosure. Reporters who follow this policy will receive:

- Credit in security advisories (unless anonymity is preferred)
- Mention in CONTRIBUTORS.md
- Our sincere gratitude

## Contact

- **Security reports**: security@jeremylongshore.com
- **General inquiries**: jeremy@jeremylongshore.com
- **Response time**: 24 hours for initial acknowledgment
