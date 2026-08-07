# Add Skill

Add new Cursor skills based on user requests.

## Usage

When the user invokes `/add skill`, this skill will:
1. Ask clarifying questions about the desired skill (name, description, triggers, paths)
2. Create a new SKILL.md file in `.cursor/skills/{trigger}/` directory
3. Write the skill definition following the established format

## Format

```markdown
# {Skill Name}

{Brief description of what this skill does}

- Feature 1
- Feature 2
- ...

## Paths

- @workspace:*.md - Project documentation files
```

## Paths

- @workspace:.cursor/skills/* - Existing skills directory structure
