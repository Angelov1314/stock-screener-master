from dataclasses import dataclass
from typing import Dict, List, Optional
from urllib.parse import quote_plus

from playwright.async_api import Page


SEARCH_URL = "https://www.linkedin.com/jobs/search/?keywords={keyword}&f_AL=true&refresh=true"


@dataclass
class JobMetadata:
    keyword: str
    title: str
    company: str
    location: str
    job_url: str
    job_id: str
    description: Optional[str] = None


async def goto_search(page: Page, keyword: str) -> None:
    url = SEARCH_URL.format(keyword=quote_plus(keyword))
    await page.goto(url, wait_until="domcontentloaded", timeout=60000)
    await page.wait_for_timeout(3000)


async def harvest_job_cards(page: Page, selectors: Dict[str, str]) -> List[JobMetadata]:
    job_items = page.locator(selectors["job_list_items"])
    count = await job_items.count()
    jobs: List[JobMetadata] = []
    for idx in range(count):
        item = job_items.nth(idx)
        title = (await item.locator("h3").inner_text()).strip()
        company = (await item.locator("h4").inner_text()).strip()
        location = (await item.locator("div>div").nth(1).inner_text()).strip()
        job_url = await item.locator("a").get_attribute("href")
        job_id = (await item.get_attribute("data-occludable-job-id")) or ""
        jobs.append(
            JobMetadata(
                keyword="",
                title=title,
                company=company,
                location=location,
                job_url=f"https://www.linkedin.com{job_url}" if job_url else "",
                job_id=job_id,
            )
        )
    return jobs


async def open_job(page: Page, item_index: int, selectors: Dict[str, str]) -> JobMetadata:
    job_items = page.locator(selectors["job_list_items"])
    item = job_items.nth(item_index)
    await item.click()
    await page.wait_for_timeout(2000)

    title = (await page.locator("h1.top-card-layout__title").inner_text()).strip()
    company = (await page.locator("a.topcard__org-name-link").inner_text()).strip()
    location = (await page.locator("span.topcard__flavor--bullet").inner_text()).strip()

    description = await page.locator("div.show-more-less-html__markup").inner_text()
    job_url = page.url
    job_id = await page.get_attribute("data-job-id", "")

    return JobMetadata(
        keyword="",
        title=title,
        company=company,
        location=location,
        job_url=job_url,
        job_id=job_id or "",
        description=description,
    )
