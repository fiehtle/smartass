# SmartAss

A smart article reader with AI-powered context and insights.

## Setup

### API Key Configuration

To run this app, you'll need to configure your OpenAI API key. There are three ways to do this:

1. **Environment Variable (Recommended for development)**
   - Set the `OPENAI_API_KEY` environment variable:
   ```bash
   export OPENAI_API_KEY=your_api_key_here
   ```

2. **Config.plist (Alternative method)**
   - Copy `Config.example.plist` to `Config.plist`
   - Replace `YOUR_API_KEY_HERE` with your actual OpenAI API key
   ```bash
   cp Config.example.plist Config.plist
   ```

3. **Debug Mode Only**
   - In debug builds, you can set the key directly in `Config.swift`
   - This is not recommended for production use

### Important Security Notes

- Never commit your API keys or sensitive credentials to version control
- The `Config.plist` file is ignored by git to prevent accidental exposure
- Always use environment variables in production environments
- Regularly rotate your API keys for security

## Development

[Add your development instructions here] 
