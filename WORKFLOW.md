---
tracker:
  kind: linear
  project_slug: "photorava-32798b198d2d"

workspace:
  root: ~/code/symphony-workspaces

hooks:
  after_create: |
    git clone --depth 1 https://github.com/jjwon2149/PhotoRava.git .

codex:
  command: codex app-server
---
You are working on a Linear issue {{ issue.identifier }} for the PhotoRava repository.
Title: {{ issue.title }}
Body: {{ issue.description }}