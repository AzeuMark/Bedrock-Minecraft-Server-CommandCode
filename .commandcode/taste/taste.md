# Taste (Continuously Learned by [CommandCode][cmd])

[cmd]: https://commandcode.ai/

# fetch-url
- Use `https://net-secondary.web.minecraft-services.net/api/v1.0/download/links` API (filtering for `serverBedrockLinux`) instead of scraping the Minecraft webpage to fetch the latest Bedrock Server download URL. Confidence: 0.75

# download
- Use `wget` instead of `curl` for downloading Bedrock server files from Mojang's CDN (avoids HTTP/2 INTERNAL_ERROR). Confidence: 0.65

# cli-ui
- Use clean terminal output (echo/printf/read) instead of whiptail dialog boxes for CLI management interfaces. Confidence: 0.85

# cli-commands
- Format setup/deployment commands as single-line semicolon-separated chains (`cmd1; cmd2; cmd3`) for easy copy-paste execution instead of listing individual commands on separate lines. Confidence: 0.70

# messaging
- Use concise, single-line status messages instead of verbose multi-line explanations for server actions (e.g., "The server has been fully stopped and will not auto-start upon VPS reboot" instead of multi-paragraph warnings). Confidence: 0.65

