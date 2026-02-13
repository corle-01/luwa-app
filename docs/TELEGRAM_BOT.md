# Luwa AI Telegram Bot

## Bot Info

- **Bot Username:** [@LuwaAIBot](https://t.me/LuwaAIBot)
- **Bot Link:** https://t.me/LuwaAIBot
- **Webhook URL:** https://eavsygnrluburvrobvoj.supabase.co/functions/v1/telegram-bot

## How to Use

1. Open Telegram and search for `@LuwaAIBot` or click https://t.me/LuwaAIBot
2. Press "Start" or send `/start`
3. Ask anything about your business in Bahasa Indonesia

### Quick Commands

| Command  | Description |
|----------|-------------|
| `/start` | Welcome message and introduction |
| `/help`  | Show usage guide |
| `/sales` | Today's sales summary (direct from DB, no AI) |
| `/stock` | Ingredient stock status |
| `/top`   | Top selling products today |
| `/shift` | Current active shift info |
| `/reset` | Reset conversation context |

### Natural Language Queries

You can ask anything in natural language (Bahasa Indonesia), for example:

- "Berapa penjualan hari ini?"
- "Produk apa yang paling laris?"
- "Ada stok yang menipis?"
- "Gimana performa minggu ini?"
- "Kasih saran untuk naikkan penjualan"
- "Apa yang harus saya restock?"

The bot maintains conversation context per chat (up to 10 message pairs). Use `/reset` to start fresh.

## Architecture

```
User (Telegram) --> Telegram Bot API --> Supabase Edge Function
                                              |
                                              |--> Supabase DB (business data)
                                              |--> DeepSeek API (AI responses)
                                              |
User (Telegram) <-- Telegram Bot API <-- sendMessage response
```

- **Edge Function:** `supabase/functions/telegram-bot/index.ts`
- **Runtime:** Deno (Supabase Edge Functions)
- **AI Model:** DeepSeek Chat (deepseek-chat)
- **Database:** Supabase PostgreSQL (same as POS app)

### How It Works

1. Telegram sends webhook POST to the edge function
2. Function parses the message and checks for commands
3. For quick commands (`/sales`, `/stock`, etc.), queries DB directly
4. For natural language, builds business context from DB then calls DeepSeek
5. Response is sent back to user via Telegram `sendMessage` API
6. Conversation history is kept in-memory per `chat_id` (max 10 pairs)

## Redeployment

### Prerequisites

- Supabase CLI or access to Supabase Management API
- Deno runtime (for CLI deployment)

### Deploy via Supabase CLI

```bash
# Set access token (from .env)
export SUPABASE_ACCESS_TOKEN="$SUPABASE_ACCESS_TOKEN"

# Set edge function secrets first
supabase secrets set \
  TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN" \
  DEEPSEEK_API_KEY="$DEEPSEEK_API_KEY" \
  SUPABASE_URL="$SUPABASE_URL" \
  SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --project-ref "$SUPABASE_PROJECT_REF"

# Deploy (from project root)
supabase functions deploy telegram-bot --project-ref "$SUPABASE_PROJECT_REF" --no-verify-jwt
```

### Re-set Webhook (if needed)

```bash
curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook?url=https://$SUPABASE_PROJECT_REF.supabase.co/functions/v1/telegram-bot"
```

### Check Webhook Status

```bash
curl "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getWebhookInfo"
```

### View Logs

Check the Supabase Dashboard → Functions → telegram-bot

## Configuration

All secrets are loaded from environment variables (set via `supabase secrets set`):

- `TELEGRAM_BOT_TOKEN` - Telegram bot token
- `DEEPSEEK_API_KEY` - DeepSeek API key
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_ANON_KEY` - Supabase anon key
- `OUTLET_ID` - Outlet ID (optional, defaults to first outlet)
- `MAX_HISTORY` - Max conversation pairs kept in memory (default: 10)
