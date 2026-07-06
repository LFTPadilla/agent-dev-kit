# Connections Reference

This public file is intentionally a template.

Do not commit real hostnames, IP addresses, usernames, private keys, cluster
names, customer names, or production commands here.

Private overlays may provide a project-specific file with:

- bastion host
- SSH aliases
- VPN/Tailscale requirements
- staging endpoints
- production endpoints
- shutdown target rules
- escalation contacts

The `overnight-task` skill may read that private file only when the project
explicitly provides it.
