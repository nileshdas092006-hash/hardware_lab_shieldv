# How to make the commits in the commit plans

Git keeps the history of the project as a list of snapshots called **commits**. Each
commit says *who* changed *what* and *why*. Git marks come from small, regular commits by
every member, so the commit plans ([G1](../G1/COMMIT_PLAN.md), [G2](../G2/COMMIT_PLAN.md),
[G3](../G3/COMMIT_PLAN.md)) break the work into steps worth one commit each.

All the files already exist in Das's folder `C:\Dev\hardware_lab_shieldv`. The plan is
to commit them **gradually, one row at a time, on the planned dates**, each by its
owner, after studying them.

## Step 0 · the first push (Nilesh, once, commit G2-NL00)

This puts only the skeleton (READMEs, docs, empty folders) on GitHub. In PowerShell:

```powershell
cd C:\Dev\hardware_lab_shieldv
git init -b main
git remote add origin https://github.com/nileshdas092006-hash/hardware_lab_shieldv.git
git add README.md .gitignore docs/interfaces.md docs/how-to-commit.md docs/getting-started.md docs/golden-template.md
git add G1/README.md G1/COMMIT_PLAN.md G1/Avani/README.md G1/Laxmidhar/README.md
git add G2/README.md G2/COMMIT_PLAN.md G2/Nishant/README.md G2/Nilesh/README.md
git add G3/README.md G3/COMMIT_PLAN.md G3/Priynk/README.md
git add "*.gitkeep"
git status            # only the files above should be listed under "Changes to be committed"
git commit -m "chore: add repo skeleton, READMEs, interfaces and commit plans"
git push -u origin main
```

`git status` also lists every other file as "untracked": that is expected. They get
committed later, row by row.

## Step 1 · every member, once

1. Make sure you have a GitHub account and Nilesh has added you as a collaborator.
2. Clone the repository and tell git who you are (use the email of your GitHub account):

   ```powershell
   git clone https://github.com/nileshdas092006-hash/hardware_lab_shieldv.git
   cd hardware_lab_shieldv
   git config user.name  "Your Name"
   git config user.email "you@example.com"
   ```

3. Get **your own files** from Das (a zip of the full folder) and copy **only your
   folder** into your clone, e.g. Avani copies `G1/Avani/`, Priyank copies `G3/Priynk/`.
   Shared files you own (listed with `/` in your plan, e.g. `/scripts/riscv_tests.py`)
   come too. Do not copy other people's files: you will receive them through `git pull`
   when they commit them, and an untracked copy would block that pull.

## Step 2 · each row of your plan

```powershell
git switch main
git pull                                  # get everyone's latest commits
git switch -c g1/avani-alu                # a branch for this block (name from your plan)

# ... study the block, write the "(you write)" files, run the check ...

git status                                # what changed or is new
git add G1/Avani/golden/A6_alu.md         # exactly the files in the row
git commit -m "docs(alu): add golden I/O table for the ALU"
```

Repeat for the next rows of the same block on the same branch, then:

```powershell
git push -u origin g1/avani-alu
```

On GitHub, open a **pull request** for the branch, ask another member to review it,
then merge it. Back on your laptop: `git switch main` and `git pull`.

## Writing a good commit message

Format: `type(block): what you did, in the present tense`

| type | use it for |
|---|---|
| `docs` | golden tables, READMEs, learning logs, diagrams, reports |
| `test` | testbenches and test programs |
| `feat` | new RTL or new software |
| `fix` | correcting a bug found by a test |
| `build` | Makefile, scripts, Vivado files, CI |
| `chore` | housekeeping that changes no behaviour |

Good: `fix(divider): return -1 quotient on divide by zero`
Bad: `update`, `final`, `changes`, `asdf`

## Rules that keep us out of trouble

- **Only commit files you own.** Shared files (`docs/interfaces.md`) change only after
  everyone affected agrees.
- **Run the check before you commit.** Never edit a test just to make it pass.
- **Commit when a step works**, on its planned date, not everything at the end.
- **Never commit `build/`** (the `.gitignore` already skips it).
- **Pull before you start each day** (`git pull` on `main`, then `git merge main` on your branch).
