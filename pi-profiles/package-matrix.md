# Pi Package Matrix

| Package | Profile | Use | Default Policy |
| --- | --- | --- | --- |
| `npm:context-mode` | `pi-diagnose`, `pi-sre-research` | Give delegated agents tighter task context. | `read-only` / `research-network` |
| `npm:@bacnh85/pi-serena` | `pi-diagnose`, `pi-code-review` | Semantic code navigation and repository-aware review. | `read-only` |
| `npm:@bacnh85/pi-plan` | `pi-code-review` | Review plans and break work into bounded steps. | `read-only` |
| `npm:@braintrust/pi-extension` | `pi-diagnose`, `pi-code-review` | Evaluation-oriented review and rubric thinking. | `read-only` |
| `npm:pi-web-access` | `pi-sre-research` | Current documentation and web research. | `research-network` |
| `npm:pi-all-search` | `pi-sre-research` | Broader package/source discovery. | `research-network` |
| `npm:pi-subagents` | `pi-parallel-workers` | Fan out bounded tasks. | `read-only` |
| `npm:@gjczone/pi-swarm` | `pi-parallel-workers` | Coordinate multiple short-lived worker agents. | `read-only` |
| `npm:@lebronj/pi-playwright` | `pi-browser-lab` | Browser automation and screenshot capture. | `browser-lab` |

## Deferred

| Package | Reason |
| --- | --- |
| `npm:gentle-engram` | Needs a retention/deletion policy before persistent memory is acceptable. |
| `npm:pi-nocturne-memory` | Same persistent-memory concern. |
| `npm:@llblab/pi-actors` | Actor systems are useful after simpler delegation profiles have baseline evals. |

## Review Checklist

- Does the profile need network access?
- Can it run in a disposable workspace?
- Is its output structured enough for the primary agent to verify?
- Does the prompt exclude secrets, production consoles, and customer data?
