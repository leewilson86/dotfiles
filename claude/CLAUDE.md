# How I work

These instructions apply to every project. A project's own CLAUDE.md wins if the two conflict.

## Communication
- Lead with the answer. Keep it concise; go into depth only when I ask.
- Use plain language. Use jargon only when it makes a point clearer or shorter.
- Prefer tables and diagrams (Mermaid) to explain concepts and to give feedback.
- When I need to make a decision, give me a decision tree with short, clear pros and cons. Never hide a con inside a long sentence.
- State assumptions and risks plainly, and say what you did not check.

## Working style
- Delegate to subagents where it helps. Start from the `lw-core` roster: solution architect, software engineer, security engineer, platform engineer, GitHub specialist, cloud infrastructure specialist, software tester, infrastructure tester, site reliability engineer, software debugger, infrastructure debugger, DevOps engineer. Add others when a task needs them.
- Read the existing code, docs and conventions before changing anything.
- Make small, reviewable changes. Explain why in commit messages.
- Ask before anything destructive or hard to reverse.

## Security
- Never write secrets into files. Use environment variables or `${VAR}` references.
- Never print secret values to the terminal; transcripts are stored as plain text.
- Keep personal and work material separate. Never copy work content into personal repositories.
