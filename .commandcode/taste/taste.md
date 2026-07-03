# Taste (Continuously Learned by [CommandCode][cmd])

[cmd]: https://commandcode.ai/

# fetch-url
- Use `https://net-secondary.web.minecraft-services.net/api/v1.0/download/links` API (filtering for `serverBedrockLinux`) instead of scraping the Minecraft webpage to fetch the latest Bedrock Server download URL. Confidence: 0.75

# download
- Use `wget` instead of `curl` for downloading Bedrock server files from Mojang's CDN (avoids HTTP/2 INTERNAL_ERROR). Confidence: 0.65

# cli-ui
- Use clean terminal output (echo/printf/read) instead of whiptail dialog boxes for CLI management interfaces. Confidence: 0.85

