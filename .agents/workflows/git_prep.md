---
description: 
---

# Git Merge Preparation Routine

When triggered by the user to prepare for a Git commit or merge, follow these exact steps:

1. **Test Execution:** Execute the tests created or alreayd present to run all Python and Dart tests.
2. **Analysis:** If tests fail, analyze the logs, fix the code, and re-run. Do not proceed to step 3 until tests pass.
3. **Diff Review:** Generate a clean, concise summary of all changed files and what functionality was altered.
4. **Git Staging:** Only after tests pass and the user approves the summary, stage the files and propose a semantic commit message. Do not commit or push without final user approval.
5. **Docker Commands:** Never give me commands which makes me download all the packages again unless asked we should focus on quick redeployment.