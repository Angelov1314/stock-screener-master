from __future__ import annotations

import asyncio
import random
from pathlib import Path
from typing import Dict, Optional

from playwright.async_api import BrowserContext, Page, async_playwright
from rich.console import Console

from . import form_fillers
from .jobs import goto_search, harvest_job_cards, open_job
from .utils import build_resources, make_logger, parse_args

console = Console()


def _status(msg: str) -> None:
    console.log(msg)


async def wait_random(pause_cfg) -> None:
    await asyncio.sleep(random.uniform(pause_cfg.min_seconds, pause_cfg.max_seconds))


async def prepare_context(context: BrowserContext, cookies) -> None:
    await context.add_cookies(cookies)
    _status("[green]Cookies loaded into browser context")


async def ensure_logged_in(page: Page) -> None:
    await page.goto("https://www.linkedin.com/feed/", wait_until="domcontentloaded")
    await page.wait_for_timeout(2000)
    if "login" in page.url:
        raise RuntimeError("LinkedIn session invalid; refresh cookies")
    _status("[green]LinkedIn session active")


async def apply_to_job(
    page: Page,
    job_index: int,
    resume_text: str,
    resources,
    logger,
) -> bool:
    config = resources.config
    selectors = config.selectors

    job_meta = await open_job(page, job_index, selectors)
    _status(f"Evaluating job: {job_meta.title} @ {job_meta.company}")

    easy_button = page.locator(selectors["easy_apply_button"])
    if not await easy_button.count():
        logger({
            "job": job_meta.title,
            "company": job_meta.company,
            "status": "skipped",
            "reason": "no_easy_apply",
        })
        return False

    await easy_button.first.click()
    await page.wait_for_timeout(1500)

    success = await run_easy_apply_modal(page, job_meta, resume_text, resources, logger)
    return success


async def run_easy_apply_modal(page: Page, job_meta, resume_text: str, resources, logger) -> bool:
    config = resources.config
    selectors = config.selectors

    modal = page.locator("div.jobs-easy-apply-modal")
    if not await modal.count():
        logger({
            "job": job_meta.title,
            "company": job_meta.company,
            "status": "skipped",
            "reason": "modal_not_found",
        })
        return False

    step = 0
    while True:
        step += 1
        await form_fillers.fill_standard_fields(page, config)
        await form_fillers.handle_salary_fields(page, config)
        await form_fillers.handle_skill_experience(page, resume_text)
        await form_fillers.handle_cover_letter_if_needed(page, job_meta, resume_text, config)

        await wait_random(config.pause_between_actions)

        submit_button = page.locator(selectors.get("submit_button", ""))
        if submit_button and await submit_button.count():
            if config.dry_run:
                _status("[yellow]Dry run: skipping final submit")
            else:
                await submit_button.first.click()
            logger({
                "job": job_meta.title,
                "company": job_meta.company,
                "status": "submitted" if not config.dry_run else "dry_run",
            })
            await dismiss_modal(page)
            return True

        review_button = page.locator(selectors.get("review_button", ""))
        if review_button and await review_button.count():
            await review_button.first.click()
            await wait_random(config.pause_between_actions)
            continue

        next_button = page.locator(selectors.get("next_button", ""))
        if next_button and await next_button.count():
            await next_button.first.click()
            await wait_random(config.pause_between_actions)
            continue

        _status("[red]Stuck in modal; closing application")
        await dismiss_modal(page)
        logger({
            "job": job_meta.title,
            "company": job_meta.company,
            "status": "skipped",
            "reason": "unknown_modal_state",
        })
        return False


async def dismiss_modal(page: Page) -> None:
    close_button = page.locator("button[aria-label='Dismiss']")
    if await close_button.count():
        await close_button.first.click()
        await page.wait_for_timeout(1000)


async def run(resources) -> None:
    logger = make_logger(Path(resources.config.logging_dir))

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=resources.config.headless)
        context = await browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_6_0) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
            locale="en-US",
            extra_http_headers={"accept-language": "en-US,en;q=0.9"},
        )
        await prepare_context(context, resources.cookies)
        page = await context.new_page()
        await ensure_logged_in(page)

        applications_done = 0
        limit = resources.config.applications_per_run

        for keyword in resources.config.search_keywords:
            if applications_done >= limit:
                break
            _status(f"Searching keyword: {keyword}")
            await goto_search(page, keyword)
            job_cards = await harvest_job_cards(page, resources.config.selectors)

            for idx in range(len(job_cards)):
                if applications_done >= limit:
                    break
                success = await apply_to_job(
                    page=page,
                    job_index=idx,
                    resume_text=resources.resume_text,
                    resources=resources,
                    logger=logger,
                )
                if success:
                    applications_done += 1
                    _status(f"[green]Applications so far: {applications_done}/{limit}")
                    await wait_random(resources.config.pause_between_actions)

        await browser.close()
        _status(f"Run complete: {applications_done} submitted")


def main() -> None:
    args = parse_args()
    resources = build_resources(args.config, args.dry_run, args.headless)
    asyncio.run(run(resources))


if __name__ == "__main__":
    main()
