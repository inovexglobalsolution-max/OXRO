# Push code to repo and create branch `sachin`

## Goal
Push current codebase to the Git remote, create sub-branch `sachin`, and push to it using the provided token.

## Security Notes
- The GitHub token was shared in chat. Treat it as **compromised** - revoke it immediately in GitHub and generate a new token (or use SSH).
- Avoid embedding tokens in remote URLs in shared history. Prefer credential helpers.
- This plan only outlines steps - execution requires an implementation-capable agent.

## Prerequisites
- Repo is git-initialized at `D:\OXRO\oxro`
- Remote repository exists and you have push access
- Token has `repo` scope

## Plan
1. **Verify repo state**
   - `git -C D:\OXRO\oxro status`
   - `git -C D:\OXRO\oxro remote -v`
   - `git -C D:\OXRO\oxro branch -a`

2. **Create and switch to branch `sachin`**
   - `git -C D:\OXRO\oxro checkout -b sachin` (or `git switch -c sachin`)

3. **Stage and commit changes**
   - `git -C D:\OXRO\oxro add -A`
   - `git -C D:\OXRO\oxro commit -m "chore: update from local"` (only if there are unstaged changes)

4. **Configure remote with token (if needed)**
   - If using HTTPS: update origin URL to `https://<token>@github.com/<owner>/<repo>.git`
   - Or use `git push https://<token>@...` without changing remote permanently

5. **Push to remote**
   - `git -C D:\OXRO\oxro push -u origin sachin`

## Risks
- Token exposure in logs/history
- Pushing to wrong repo
- Uncommitted sensitive files (check `.gitignore`)

## Validation
- `git branch --show-current` returns `sachin`
- Remote shows branch `origin/sachin`
- Commit visible on remote

## Execution
This requires mutating git operations. Switch to an implementation-capable agent to execute these steps.
