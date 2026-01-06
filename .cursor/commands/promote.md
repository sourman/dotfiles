Move a file or MCP server entry from the project's .cursor directory to the global ~/.cursor directory.

For files:
1. Parse the input to determine the filename and folder type (commands, rules, plans, tools, or mcps)
2. Check if the file exists in .cursor/{folder}/{filename} in the current project
3. If the file doesn't exist, check if it's already in ~/.cursor/{folder}/ and inform the user
4. If the file exists in the project, move it to ~/.cursor/{folder}/{filename}
5. Create the target directory in ~/.cursor if it doesn't exist
6. Confirm the move was successful

For MCP server entries:
1. Parse the input to identify it as an MCP server name (check if it exists in .cursor/mcp.json)
2. Read .cursor/mcp.json and extract the server entry from mcpServers.{serverName}
3. Check if the server entry already exists in ~/.cursor/mcp.json and warn if it does (ask for confirmation to overwrite)
4. Read ~/.cursor/mcp.json (create with empty mcpServers if it doesn't exist)
5. Add the server entry to ~/.cursor/mcp.json's mcpServers object
6. Remove the server entry from .cursor/mcp.json (if mcpServers becomes empty, you can remove the file or leave it with empty mcpServers)
7. Write both files back with proper JSON formatting
8. Confirm the move was successful

If the user provides just a filename, search in all supported folders (commands, rules, plans, tools, mcps) to find it.
If multiple matches are found, ask the user which one to promote.
If the input doesn't match any file but matches an MCP server name in mcp.json, treat it as an MCP promotion.