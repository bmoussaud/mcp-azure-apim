# Proposal: Normalize commit messages across repository

I rewrote the entire repository history locally on branch `rewrite/commit-format` to normalize commit messages to the project's commit format (see `.github/copilot-instructions.md`). The rewritten branch has been pushed as `rewrite/commit-format`.

Why this PR exists

- Git history rewrite cannot be applied via a normal merge. To replace `main` with the rewritten history requires a forced push (destructive). This PR documents the rewrite and provides a preview so maintainers can review and decide whether to apply the rewritten history.

How to apply the rewritten history (if approved)

1. Fetch the rewritten branch:

   git fetch origin rewrite/commit-format:rewrite/commit-format

2. Verify locally and then force-push to main (this will rewrite remote history):

   git push --force origin rewrite/commit-format:main

   Note: force-pushing will require all collaborators to rebase or re-clone; do not do this without coordination.

Preview of commit message changes

Preview saved to commit-message-preview.txt
repo(repo): Add test script for Setlist API integration
9063b16be07d2753c5bcbaf99e10ee17508e0a07 -> infra(main.bicep): Add test script for Setlist API integration
82fbcbd36c9e00ae525b262db72ee8a61b0e5ca5 -> apim(repo): Update README and mcp_client.py for Setlist API enhancements and cleanup
c605fbb933d0444b49c6fac16b711ab3d3c540a1 -> infra(main.bicep): Add Azure AI agent implementation for Setlist.fm API integration
3b34e7cf9528ab49e32c8b471233b00dc4191a2c -> apim(repo): Add Azure AI agent implementation for Setlist.fm API integration
ef6c55b8d28e9101651135a38ecab2715b6a76f2 -> infra(modules): code structure for improved readability and maintainability
6d37e5caaf368209bba586a5910050f1325c9435 -> repo(repo): Remove unused mcp.json configuration and associated script for cleane...
31e7b7774f1216dc2c31cb849c7bec215a5449eb -> repo(repo): Update README for MCP Server configuration clarity and add cleanup in...
9ebd8d6d17515cd665b835fdc423661fa5c12098 -> repo(repo): Add init script for pulling Model Context Protocol inspector image an...
2c96a3b414c5cef0c1bf8b7fb677d4a563d0b582 -> apim(repo): Update README and scripts for MCP rate limiting and improve error han...
d6d23e3a31be92e8e5eb422b753b7eb1b43cc4a8 -> repo(repo): Add MCP integration blog link to documentation section in README
6cb8ea517ab4cdc26c9a8820623091e83f5676d7 -> python(repo): initialization scripts and update README for clarity on Setlist.fm AP...
13d996364e12613cd3ff948eda9adcdbd3103637 -> apim(repo): Implement code changes for improved functionality and performance enh...
ed09ba90543e4ced6da2a10ee21a37fd636ccf99 -> apim(repo): Remove deprecated request-token.http file for Setlist.fm API access
de86a2bdad16134d5cacc985a4a8bc0b4f7fb12d -> repo(repo): add comprehensive Copilot instructions for repository usage and guide...