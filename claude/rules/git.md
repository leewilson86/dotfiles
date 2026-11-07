# Git conventions

- Commit messages: a short imperative summary line (under 72 characters), a blank line, then why the change was made.
- One logical change per commit.
- Never force push to shared branches. Use `--force-with-lease` on your own branches if you must.
- Never commit secrets, `.env` files or credentials. Check `git diff --cached` before committing.
- Branch names: `type/short-description`, for example `feat/plugin-sync` or `fix/hook-timeout`.
