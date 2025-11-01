# Environment Secrets Setup Guide

## Important Security Notes

- **NEVER commit `.env` files** with real secrets to your repository
- The `.gitignore` is configured to prevent accidental commits
- All secrets should be set in Netlify environment variables
- The app will work without some variables (with graceful degradation)

## Netlify Environment Variables Setup

To deploy to Netlify with all features enabled, set these environment variables in your Netlify site:

**Site Settings → Build & deploy → Environment**

### Required Public Variables

These can be exposed to the client (they're intentionally public):

```
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key_here
VITE_COINGECKO_API=https://api.coingecko.com/api/v3
VITE_WALLET_CONNECT_PROJECT_ID=your_project_id_here
VITE_PUBLIC_BUILDER_KEY=your_builder_key_here
```

### Required Secret Variables (Server-side only)

These are NEVER exposed to the client and must be kept secret:

```
NEXT_SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
CRON_API_KEY=your_cron_api_key_here
```

### Optional Variables

```
PING_MESSAGE="ping pong"
```

## Getting Your Credentials

### Supabase
1. Go to https://app.supabase.com
2. Select your project
3. Go to **Settings → API**
4. Copy:
   - `Project URL` → `VITE_SUPABASE_URL`
   - `anon public` key → `VITE_SUPABASE_ANON_KEY`
   - `service_role secret` key → `NEXT_SUPABASE_SERVICE_ROLE_KEY`

### WalletConnect
1. Go to https://cloud.walletconnect.com
2. Create or select a project
3. Copy your **Project ID** → `VITE_WALLET_CONNECT_PROJECT_ID`

### CoinGecko
- The free API endpoint is: `https://api.coingecko.com/api/v3`
- Set `VITE_COINGECKO_API` to this value

### Builder.io
1. Get your API key from https://builder.io/account
2. Set `VITE_PUBLIC_BUILDER_KEY` to your key

## Local Development

For local development, create `.env.local`:

```bash
cp .env.example .env.local
```

Then edit `.env.local` with your real credentials. This file is in `.gitignore` and will NOT be committed.

## Verification

After setting Netlify environment variables:

1. Trigger a new deploy
2. Check the deploy logs for any `SECRETS_SCAN` warnings
3. Monitor the application for working features:
   - Supabase authentication
   - Crypto price fetching
   - Wallet connection

## Troubleshooting

If you see "SUPABASE env vars are missing" warnings:
- This is normal if you haven't set the env variables yet
- Features will gracefully degrade
- Set the variables in Netlify to enable them

If Netlify still shows secrets scan errors:
1. Ensure no real secrets are in any committed files
2. Check build logs for any console output that exposes secrets
3. Verify `.gitignore` is properly excluding `.env*` files

## Secret Rotation

If any secrets are ever compromised:

1. **Immediately rotate the key** in the original service (Supabase, WalletConnect, etc.)
2. Update the new value in Netlify environment variables
3. Redeploy your application
4. If the secret was committed to git history, contact the service provider to revoke it

Never rely solely on removing a file from the repository - the secret remains in git history.
