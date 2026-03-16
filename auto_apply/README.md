# LinkedIn Easy Apply Automation

This folder contains a Playwright-based workflow that searches for "data analyst" and "data scientist" roles with Easy Apply enabled, submits up to 10 applications per run, and repeats three times per day.

## Features

- Loads an already-authenticated LinkedIn session using exported cookies (no password storage in the script).
- Iterates through recent job results for each keyword and stops after 10 successful applications per run.
- Handles multi-step Easy Apply flows (next/back/submit) with basic validation.
- Auto-fills standard fields (phone, location, salary expectations, work authorization, etc.).
- Detects skill-specific "years of experience" questions and responds with `3` years if the skill appears in your resume text, otherwise `1`.
- Generates a <=100-word cover letter for roles that require one, combining JD snippets with resume highlights.
- Logs every attempt (success, skipped, reason) to `logs/applications-YYYY-MM-DD.jsonl` for auditing.

## File Layout

```
auto_apply/
├─ README.md                  ← This guide
├─ config.example.json        ← Copy to config.json and edit
├─ cookies.example.json       ← Placeholder; replace with export from browser
├─ requirements.txt           ← Python dependencies
├─ resume_context.example.md  ← Paste a plaintext version of your CV for keyword/cover letter logic
├─ src/
│  ├─ __init__.py
│  ├─ apply.py                ← Main entry point (`python -m auto_apply`)
│  ├─ cover_letter.py         ← 100-word cover letter helper
│  ├─ form_fillers.py         ← Logic for common LinkedIn questions
│  ├─ jobs.py                 ← Search/helpers for job cards
│  └─ utils.py                ← Shared helpers (cookies, logging, etc.)
└─ logs/                      ← Created automatically at runtime
```

## Quick Start

1. **Install dependencies**
   ```bash
   cd auto_apply
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   python -m playwright install chromium
   ```

2. **Configure secrets**
   - Export your LinkedIn cookies into `auto_apply/cookies.json` (same format as `cookies.example.json`). Browser extensions like "Cookie Editor" work well.
   - Copy `config.example.json` → `config.json` and adjust values (keywords, schedule, contact info, resume paths, etc.).
   - Paste a plaintext version of your CV into `resume_context.md`. The script uses it to detect which skills appear and to craft cover letters.

3. **Dry run**
   ```bash
   python -m auto_apply --dry-run
   ```
   This walks through search + form filling without clicking the final "Submit application" buttons.

4. **Schedule (cron)**
   Example crontab for three runs per day (Shanghai time). Adjust Python/venv paths as needed.
   ```cron
   0 9,14,20 * * * cd /Users/jerry/.openclaw/workspace/auto_apply && source .venv/bin/activate && python -m auto_apply >> logs/cron.log 2>&1
   ```

## Skill-year & Cover Letter Logic

- **Skill questions**: When a numeric input/selector mentions a skill (e.g., "Years of experience with SQL"), the script checks whether the skill term exists in `resume_context.md`. If it does, it answers `3`. Otherwise it answers `1`.
- **Cover letters**: If an application step requires a cover letter upload or textarea, `cover_letter.generate_cover_letter()` composes a <=100-word paragraph emphasizing:
  - Role title + company name
  - Two JD keywords that intersect with your resume highlights
  - One achievement pulled from your resume summary
  The generated text is deterministic and does **not** call external APIs.

## Notes

- LinkedIn frequently updates CSS/data attributes. If selectors break, update the `jobs.py` / `form_fillers.py` locators.
- Long sessions can trigger LinkedIn anti-bot checks. Randomized waits and mouse movements are built in, but monitor logs.
- Keep cookies fresh. If login fails, export a new set.
- For more resilient cover letters or custom answers, you can swap in an LLM call inside `cover_letter.py` as long as you set `OPENAI_API_KEY` in the environment.
