# IMCC CareerHub

Job marketplace for IMCC students and alumni, with an AI career agent.

## How it is deployed
- Vercel runs `npm run build` (`build.js`), which copies the site into `public/` (the output directory).
- `api/career-agent.js` is the serverless AI function.
- Database: Supabase (run `supabase-backend.sql`, then `supabase-analytics.sql`).

## Vercel environment variables
| Key | Type | Value |
|---|---|---|
| `GROQ_API_KEY` | Secret | key from console.groq.com/keys |
| `GROQ_MODEL` | Config, optional | default `openai/gpt-oss-120b` |
| `GROQ_FALLBACK_MODEL` | Config, optional | default `openai/gpt-oss-20b` |
| `CAREER_AI_DEBUG` | Config, optional | `1` to troubleshoot, then delete it |

Redeploy after changing any variable.

## What the AI agent does
| Feature | Who can use it | If the AI is down |
|---|---|---|
| Job matching ("Ask IMCC Career AI") | everyone | built-in keyword matcher still returns matches |
| Skills gap ("How ready am I?") | @imcc.edu.ph sign-in | rule-based comparison |
| Profile feedback | @imcc.edu.ph sign-in | rule-based tips (no rewritten summary) |
| Interview practice | @imcc.edu.ph sign-in | standard 5 questions; answer feedback shows a retry message |
| Application message draft | @imcc.edu.ph sign-in | template draft (120-180 words) |

## Troubleshooting
1. Open `https://YOUR-SITE/api/career-agent` in a browser. `{"status":"ok","aiConfigured":true}` means the key is set.
2. Set `CAREER_AI_DEBUG=1`, redeploy, then open `https://YOUR-SITE/api/career-agent?diag=1`. It reports whether Groq works and why not.
3. Vercel -> project -> Logs shows `career-agent` messages.
