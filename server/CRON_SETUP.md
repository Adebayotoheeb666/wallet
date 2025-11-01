# CryptoVault Cron Jobs Setup Guide

This guide explains how to set up automated cron jobs for price updates, alert checking, and maintenance tasks.

## Available Cron Jobs

### 1. **Update Prices** (Every Hour)

- **Endpoint**: `POST /api/prices/update`
- **Description**: Fetches latest cryptocurrency prices from CoinGecko and updates the database
- **Timeout**: 30 seconds
- **Cron Expression**: `0 * * * *` (Every hour at minute 0)

**Example Request**:

```bash
curl -X POST https://yourdomain.com/api/prices/update \
  -H "X-API-Key: your-cron-api-key" \
  -H "Content-Type: application/json" \
  -d '{"symbols": ["BTC", "ETH", "USDT"]}'
```

### 2. **Check Price Alerts** (Every 5 Minutes)

- **Endpoint**: `POST /api/prices/alerts`
- **Description**: Checks active price alerts and triggers notifications when targets are reached
- **Timeout**: 20 seconds
- **Cron Expression**: `*/5 * * * *` (Every 5 minutes)

**Example Request**:

```bash
curl -X POST https://yourdomain.com/api/prices/alerts \
  -H "X-API-Key: your-cron-api-key" \
  -H "Content-Type: application/json"
```

### 3. **Cleanup Sessions** (Daily at 2 AM UTC)

- **Endpoint**: `POST /api/maintenance/cleanup-sessions`
- **Description**: Removes expired and old inactive user sessions
- **Timeout**: 30 seconds
- **Cron Expression**: `0 2 * * *` (Daily at 2:00 AM UTC)

### 4. **Lock Accounts** (Every 10 Minutes)

- **Endpoint**: `POST /api/maintenance/lock-accounts`
- **Description**: Locks accounts with excessive failed login attempts
- **Timeout**: 15 seconds

### 5. **Unlock Accounts** (Every Hour)

- **Endpoint**: `POST /api/maintenance/unlock-accounts`
- **Description**: Unlocks accounts whose lock period has expired
- **Timeout**: 15 seconds

---

## Setup Options

### Option 1: Vercel (Recommended for Vercel Deployments)

1. **Create cron functions in `api/cron/` directory**:

```typescript
// api/cron/update-prices.ts
import { NextRequest } from "next/server";

const CRON_API_KEY = process.env.CRON_API_KEY;

export async function POST(request: NextRequest) {
  if (request.headers.get("authorization") !== `Bearer ${CRON_API_KEY}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const response = await fetch("https://yourdomain.com/api/prices/update", {
    method: "POST",
    headers: {
      "X-API-Key": CRON_API_KEY,
      "Content-Type": "application/json",
    },
  });

  return response;
}

// Use in vercel.json:
export const config = {
  matcher: "/api/cron/update-prices",
};
```

2. **Configure in `vercel.json`**:

```json
{
  "crons": [
    {
      "path": "/api/cron/update-prices",
      "schedule": "0 * * * *"
    },
    {
      "path": "/api/cron/check-alerts",
      "schedule": "*/5 * * * *"
    },
    {
      "path": "/api/cron/cleanup-sessions",
      "schedule": "0 2 * * *"
    }
  ]
}
```

### Option 2: Netlify Functions (Recommended for Netlify Deployments)

1. **Create functions in `netlify/functions/` directory**:

```typescript
// netlify/functions/update-prices.ts
import { Handler } from "@netlify/functions";

const CRON_API_KEY = process.env.CRON_API_KEY;

const handler: Handler = async () => {
  const response = await fetch("https://yourdomain.com/api/prices/update", {
    method: "POST",
    headers: {
      "X-API-Key": CRON_API_KEY,
      "Content-Type": "application/json",
    },
  });

  return {
    statusCode: response.status,
    body: await response.text(),
  };
};

export { handler };
```

2. **Configure in `netlify.toml`**:

```toml
[functions]
directory = "netlify/functions"

[[scheduled_functions]]
function = "update-prices"
cron = "0 * * * *"

[[scheduled_functions]]
function = "check-alerts"
cron = "*/5 * * * *"

[[scheduled_functions]]
function = "cleanup-sessions"
cron = "0 2 * * *"
```

### Option 3: External Cron Service (EasyCron, cron-job.org, etc.)

Services like **EasyCron**, **cron-job.org**, or **Cronitor** can make HTTP requests on your behalf.

1. **Go to the service website** (e.g., https://www.easycron.com/)

2. **Create a new cron job**:
   - **URL**: `https://yourdomain.com/api/prices/update`
   - **Method**: POST
   - **Headers**: `X-API-Key: your-cron-api-key`
   - **Cron Expression**: `0 * * * *`

3. **Repeat for other endpoints**

### Option 4: GitHub Actions (Free, Self-Hosted Alternative)

Create `.github/workflows/cron.yml`:

```yaml
name: Cron Jobs

on:
  schedule:
    - cron: "0 * * * *" # Update prices every hour

jobs:
  update-prices:
    runs-on: ubuntu-latest
    steps:
      - name: Update Prices
        run: |
          curl -X POST https://yourdomain.com/api/prices/update \
            -H "X-API-Key: ${{ secrets.CRON_API_KEY }}" \
            -H "Content-Type: application/json"

  check-alerts:
    runs-on: ubuntu-latest
    steps:
      - name: Check Price Alerts
        run: |
          curl -X POST https://yourdomain.com/api/prices/alerts \
            -H "X-API-Key: ${{ secrets.CRON_API_KEY }}" \
            -H "Content-Type: application/json"
```

### Option 5: Node-Cron (Development/Self-Hosted)

For development or self-hosted deployments:

```bash
npm install node-cron
```

```typescript
// server/cron-scheduler.ts
import cron from "node-cron";
import { executeCronJob } from "./cron/config";
import { supabase } from "@shared/lib/supabase";
import { getMultipleCoinPrices } from "@shared/lib/coingecko";

// Update prices every hour
cron.schedule("0 * * * *", () => {
  executeCronJob("update-prices", async () => {
    const symbols = ["BTC", "ETH", "USDT", "USDC", "ADA", "SOL"];
    const prices = await getMultipleCoinPrices(symbols);

    for (const symbol in prices) {
      const price = prices[symbol];
      await supabase.from("price_history").insert({
        symbol,
        price_usd: price.price_usd,
        price_change_24h: price.price_change_24h,
        market_cap: price.market_cap,
        volume_24h: price.volume_24h,
        source: "coingecko",
      });
    }

    await supabase.rpc("update_asset_prices");
  });
});

// Check price alerts every 5 minutes
cron.schedule("*/5 * * * *", () => {
  executeCronJob("check-price-alerts", async () => {
    return await supabase.rpc("check_and_trigger_price_alerts");
  });
});

// Cleanup sessions daily at 2 AM
cron.schedule("0 2 * * *", () => {
  executeCronJob("cleanup-sessions", async () => {
    return await supabase.rpc("cleanup_expired_sessions");
  });
});
```

---

## Environment Variables Required

Set these in your deployment platform:

```env
# API Security
CRON_API_KEY=your-secure-random-key-here

# CoinGecko (already configured)
VITE_COINGECKO_API=https://api.coingecko.com/api/v3

# Supabase (already configured)
NEXT_SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

---

## Testing Cron Jobs Locally

### Using curl:

```bash
# Update prices
curl -X POST http://localhost:5173/api/prices/update \
  -H "X-API-Key: test-key" \
  -H "Content-Type: application/json"

# Check alerts
curl -X POST http://localhost:5173/api/prices/alerts \
  -H "X-API-Key: test-key" \
  -H "Content-Type: application/json"

# Cleanup sessions
curl -X POST http://localhost:5173/api/maintenance/cleanup-sessions \
  -H "X-API-Key: test-key" \
  -H "Content-Type: application/json"
```

### Using Node.js:

```typescript
async function testCronJob() {
  const response = await fetch("http://localhost:5173/api/prices/update", {
    method: "POST",
    headers: {
      "X-API-Key": "test-key",
      "Content-Type": "application/json",
    },
  });

  const data = await response.json();
  console.log(data);
}

testCronJob();
```

---

## Monitoring Cron Jobs

Monitor execution in several ways:

1. **Check Server Logs**: Look for `[CRON]` prefixed logs
2. **Database Audit Logs**: Check `audit_logs` table for cron-triggered actions
3. **Price History**: Verify `price_history` table has recent entries
4. **Alert Status**: Check `price_alerts` table for triggered alerts

---

## Troubleshooting

### Cron job not executing

- ✅ Verify `CRON_API_KEY` is set correctly
- ✅ Check that cron service can reach your domain (not localhost)
- ✅ Verify network policies allow outbound requests
- ✅ Check cron expression format (use online cron checkers)

### Prices not updating

- ✅ Verify CoinGecko API is accessible
- ✅ Check Supabase database connection
- ✅ Ensure `price_history` table has write permissions
- ✅ Check server logs for errors

### Alerts not triggering

- ✅ Verify price alerts exist in database
- ✅ Check that alert prices are reasonable
- ✅ Verify `price_alerts` trigger function is working
- ✅ Check notification preferences in user profile

---

## Recommended Schedule

For optimal performance:

- **Update Prices**: Every 1 hour (CoinGecko free tier: max 10-50 calls/minute)
- **Check Alerts**: Every 5-10 minutes
- **Cleanup Sessions**: Daily at 2 AM UTC (off-peak hours)
- **Lock/Unlock Accounts**: Every 10 minutes / 1 hour

Adjust based on your traffic and CoinGecko API rate limits.

---

## Security Best Practices

1. **Use strong `CRON_API_KEY`**:

   ```bash
   openssl rand -hex 32
   ```

2. **Restrict IP addresses** (if service allows):
   - Whitelist cron service IP addresses
   - Use IP-based rate limiting

3. **Monitor cron execution**:
   - Set up alerts for failed cron jobs
   - Log all cron executions to audit logs

4. **Keep secrets safe**:
   - Never commit `CRON_API_KEY` to version control
   - Use environment variables
   - Rotate keys periodically

---

## Next Steps

1. Choose a deployment platform (Vercel/Netlify/GitHub/External)
2. Set `CRON_API_KEY` environment variable
3. Configure cron jobs according to your platform
4. Test cron jobs locally with curl
5. Monitor logs and database for execution
6. Set up alerts for failures

For more information on cron expression format, visit: https://crontab.guru
