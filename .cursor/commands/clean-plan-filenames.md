1. List all files in `.cursor/plans` directory
2. Read through the filenames and identify which ones have UUID-like junk (random hexadecimal characters) at the end before `.plan.md`
3. For each file that has UUID-like junk at the end, rename it to remove that portion, keeping only the core plan name
4. For example: `fix_mcp_tool_toggle_reactivity_in_solidjs_966f5589.plan.md` → `fix_mcp_tool_toggle_reactivity_in_solidjs.plan.md`
5. Show the user which files were renamed and what they were renamed to
