---
allowed-tools: Bash
argument-hint: <name-or-count>
description: Create isolated HostK8s development worktrees
model: claude-sonnet-4-20250514
---

# HostK8s Worktree Creation

I'll create your isolated development worktree with unique ports and GitOps configuration.

First, let me run the worktree setup script:

```bash
./infra/scripts/worktree-setup.sh {{args}}
```

Now let me show you information about your new worktree environment:

```bash
git worktree list
```

```bash
ls -la trees/
```

Your worktree includes:
- **Isolated git branch**: `user/$GIT_USER/{{name}}`
- **Dedicated cluster**: Unique ports to avoid conflicts
- **GitOps enabled**: Flux automatically syncs your branch
- **Custom environment**: `.env` configured for your cluster

## Next Steps

**Switch to your worktree:**
```bash
cd trees/{{name}}
```

**Check cluster status:**
```bash
make status
```

**Deploy applications:**
```bash
make deploy simple        # Deploy sample apps
make up sample           # Full GitOps stack
```

**Useful commands in your worktree:**
- `make logs` - View aggregated logs
- `make sync` - Force GitOps sync
- `cat .env` - View your environment config
- `make clean` - Tear down (preserves worktree)
