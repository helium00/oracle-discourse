# Publishing to GitHub

## Initial Setup

From inside the `discourse-docker-community/` directory:

```bash
git init
git add .
git commit -m "Initial Discourse Docker deployment"
git branch -M main
git remote add origin <GITHUB_REPOSITORY_URL>
git push -u origin main
```

Replace `<GITHUB_REPOSITORY_URL>` with your repository URL, e.g.:
`https://github.com/your-username/discourse-docker-community.git`

---

## Protecting Secrets

**`.env` is excluded from git** via `.gitignore`. Never run `git add .env`.

Verify before every commit:

```bash
git status
```

Confirm `.env` does not appear in the staged or unstaged file list. If it
does, remove it immediately:

```bash
git rm --cached .env
git commit -m "chore: remove .env from tracking"
```

After accidental commit of `.env`, **rotate all secrets immediately** — the
credentials are in git history and must be treated as compromised.

---

## Secret Management Recommendations

| Approach | When to use |
|---|---|
| `.env` file on server (current setup) | Single-operator, private repo, restricted SSH access |
| GitHub Encrypted Secrets | CI/CD pipelines that deploy automatically |
| HashiCorp Vault | Team environments, audit requirements |
| AWS Secrets Manager | AWS-hosted infrastructure |

For a single-operator setup, the `.env` approach is sufficient provided:
- The GitHub repository is **private**.
- `.env` is never committed (verified by `.gitignore`).
- SSH access to the server uses key-based authentication only.

---

## Branch Strategy

| Branch | Purpose |
|---|---|
| `main` | Production configuration — always deployable |
| `feature/<description>` | New features or documentation |
| `fix/<description>` | Bug fixes |
| `chore/<description>` | Dependency updates, tooling changes |

---

## Recommended Branch Protections

In the GitHub repository: **Settings** → **Branches** → **Add branch protection rule** for `main`:

- ✅ Require a pull request before merging
- ✅ Require at least 1 review
- ✅ Do not allow force pushes
- ✅ Do not allow deletion

---

## Keeping the Deployment Updated

After changing `docker-compose.yml`, scripts, or documentation:

```bash
# On your local machine
git add <changed-files>
git commit -m "chore: update discourse image to 3.2"
git push

# On the server
git pull
./scripts/update.sh   # if image changed
# or
./scripts/restart.sh  # if only config changed
```
