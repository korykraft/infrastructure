
```
/home/kory/docker (for all hosted docker containers, currently forgejo)
/home/kory/projects (current project is pictubook)
/home/kory/projects (for provisioning infrastructure, currently homelab is this machine)
/home/kory/agents (for all agent related configs, etc)

```

- the main project we are working on is pictubook. it is in `projects/pictubook`. the main repo is in `pictubook-app` repo.  pictubook is ??????? . From a previous hermes install I have added a skill to your ~/.hermes/skills/software-development/pictubook. go ahead and clone the app into projects/pictubook and get it running 'git@github.com:korykraft/pictubook-app.git' 

- the vaults is where all durable notes will go. all knowledge, plans, decisions, references, reusable context, anything reusable. I added a skill for this. if you want to move it to a category, do that. 
- infrastructure is for provisioning my homelab. currently it is for provisioning this VM which runs on a windows pc. My main computer/portal is my mac, I would like to do something to keep track of my mac setup or do some provisioning automation in the future. go ahead and clone 'git@github.com:korykraft/infrastructure.git' into ~/workspace/infrastructure
- agents is for all operating material for all ai agents. currently I use opencode, codex and claude. I would like you to use this structure ```prompts/        reusable prompts for Hermes, Claude Code, OpenCode, etc.
workflows/     standard procedures like "create PR", "debug CI", "review diff"
checklists/    launch checklist, security checklist, deploy checklist
skills-source/ source-of-truth copies of Hermes skills before Ansible installs them
evals/         tests for whether agents followed instructions
templates/     AGENTS.md, DECISIONS.md, RUNBOOK.md templates``` -- I added a skill for this 'workspace-agents-management', move this into a category if you want. 

I like to use just as a command runner for all repeatable commands. You can see an example in the pictubook repo. 
Use just heavily. If there is a command that will most likely need to be repeated, create a just command and add it to your context. 

- create a log for all memory/context updates. put it in 
- Use the repo-stewardship skill for all future Git repo work. Before finishing meaningful changes, update the appropriate project context files: README.md, AGENTS.md, TASKS.md, DECISIONS.md, and RUNBOOK.md.
