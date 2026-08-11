# Antigravity CLI (`agy`) Sandbox Kit

Docker Sandboxes kit for running [Google's Antigravity CLI](https://antigravity.google/product/antigravity-cli) (`agy`) in YOLO mode inside an isolated sandbox.

The kit installs the official `agy` binary, starts it with `--dangerously-skip-permissions --mode=accept-edits`, and forces its headless OAuth flow so authentication works without a local browser. Antigravity can therefore run commands and edit files without its own approval prompts; the Docker sandbox remains the security boundary.

OAuth is managed by Docker Sandboxes' host-side credential proxy. Sign in once on the first sandbox created from the kit, and later Antigravity sandboxes can reuse that login without exposing the real access or refresh token inside their VMs.

## Quick start

```bash
sbx run --kit git+https://github.com/shelajev/agy-sbx-kit.git agy .
```

On the first run, Docker Sandboxes asks you to approve the kit's `antigravity` OAuth credential binding. Then `agy` prints a Google OAuth URL. Open it in a browser on your laptop, complete the Google sign-in, then paste the callback URL (or code) back into the sandbox terminal. The host credential proxy captures and stores that OAuth session. New sandboxes created from this kit can then start already authenticated.

## Named sandbox

For a sandbox you can reattach to later:

```bash
sbx create --name agy-current \
  --kit git+https://github.com/shelajev/agy-sbx-kit.git agy .

sbx run --name agy-current
```

Current `sbx` versions remember the custom agent kit on the named sandbox. If an older version does not resolve it automatically, reattach with both `--kit git+https://github.com/shelajev/agy-sbx-kit.git` and `--name agy-current`.

## How auth works

`agy`'s local auth path tries to open a browser and listen on `localhost:36742` for the OAuth callback — neither of which makes sense from inside a sandbox. The kit sets `SSH_CONNECTION` so `agy` detects a "remote" environment and switches to its copy/paste fallback:

1. CLI prints an `accounts.google.com` authorization URL.
2. You open it in any local browser, sign in, approve.
3. Google redirects you to a `http://localhost:36742/oauth-callback?code=...` URL that won't load — that's expected.
4. Copy the full URL from your browser's address bar and paste it back at the sandbox prompt.

Inside the sandbox, Antigravity still sees `~/.gemini/antigravity-cli/antigravity-oauth-token`, but it contains proxy-managed sentinel values rather than your real access and refresh tokens. The real credentials remain in Docker Sandboxes' host credential store, where they can be reused by other sandboxes created from the same kit.

An existing Antigravity token created before this kit declared OAuth cannot be imported automatically. After updating the kit, complete one fresh login so the proxy can capture and manage the token exchange.

To log out from inside the sandbox, run `/logout` at the `agy` prompt.

## How it works

- **Install (once at sandbox creation):**
  - `curl -fsSL https://antigravity.google/cli/install.sh | bash` — downloads the platform-specific `agy` binary into `~/.local/bin/agy` and runs the binary's `install` step for shell wiring.
- **Entrypoint:** `agy --dangerously-skip-permissions --mode=accept-edits` (the shell-docker image puts `~/.local/bin` on PATH). The first flag covers tool permission requests; the execution mode separately auto-approves file edits.
- **Permissions:** The kit seeds `~/.gemini/antigravity-cli/settings.json` with permissive tool, file, URL, MCP, and artifact-review settings. The file is created only when missing, so later user changes are preserved. The command-line flags are the per-session overrides.
- **Authentication:** Docker Sandboxes intercepts the Google token exchange and writes proxy-managed sentinel credentials at Antigravity's expected token path. The host holds and refreshes the real tokens for reuse across sandboxes.
- **Persistence:** Inherited from `sbx` defaults — conversations and other sandbox-local state survive restarts, while authentication is shared through the host credential proxy.
- **Self-update:** `agy` self-updates in the background; the updater domain is allowlisted.

## Security model

YOLO mode intentionally disables Antigravity's interactive tool approvals. Use this kit only where the Docker sandbox is the intended security boundary. The agent can freely change files mounted into its workspace and can reach the domains allowed by the kit's network policy, but it remains isolated from the rest of the host by Docker Sandboxes.

## Network policy

The kit allows only:

- `antigravity.google` — installer and docs
- `antigravity-cli-auto-updater-974169037036.us-central1.run.app` — release manifests and binaries (also used for self-update)
- `accounts.google.com`, `oauth2.googleapis.com`, `www.googleapis.com` — Google OAuth
- `cloudaicompanion.googleapis.com`, `cloudcode-pa.googleapis.com`, `generativelanguage.googleapis.com` — Antigravity / Gemini Code Assist APIs

If your workflow needs to reach package registries (npm, PyPI, crates.io, Go modules, etc.) or your own services, fork the kit and extend `permissions.network.allow` in `spec.yaml`.

## Smoke test

For `sbx exec`, close or pipe stdin so the CLI does not block waiting for input:

```bash
sbx exec agy-current -- sh -lc 'agy --help < /dev/null'
```

You should see the standard `agy` help text. Hitting the actual model requires an authenticated session, so the first interactive run across this kit's sandboxes still needs the OAuth paste-back.

## Local clone

If you clone this repo, `run.sh` runs a named sandbox using the local kit path:

```bash
./run.sh agy-current
```

Use any sandbox name as the first argument:

```bash
./run.sh my-sandbox
```

## License

Apache 2.0. See [LICENSE](LICENSE).
