from __future__ import annotations

import re
from typing import Dict, Optional

from playwright.async_api import Locator, Page

from .cover_letter import generate_cover_letter
from .utils import Config


async def fill_standard_fields(page: Page, config: Config) -> None:
    await fill_by_placeholder(page, "Phone", config.phone_number)
    await fill_by_placeholder(page, "Mobile", config.phone_number)

    await fill_by_label_contains(page, "location", config.location_preference)

    salary_inputs = page.locator("input[type='text'], input[type='number']").filter(
        has_text="salary"
    )
    count = await salary_inputs.count()
    for idx in range(count):
        inp = salary_inputs.nth(idx)
        await safe_fill(inp, str(config.default_salary))


async def handle_salary_fields(page: Page, config: Config) -> None:
    numeric_inputs = page.locator("input[type='number']")
    count = await numeric_inputs.count()
    for idx in range(count):
        input_el = numeric_inputs.nth(idx)
        label_text = await get_label_text(page, input_el)
        if not label_text:
            continue
        label_lower = label_text.lower()
        if "salary" in label_lower or "compensation" in label_lower:
            value = config.default_salary
            if "minimum" in label_lower:
                value = config.min_salary
            await safe_fill(input_el, str(value))


async def handle_skill_experience(page: Page, resume_text: str) -> None:
    numeric_inputs = page.locator("input[type='number']")
    count = await numeric_inputs.count()
    resume_lower = resume_text.lower()
    for idx in range(count):
        input_el = numeric_inputs.nth(idx)
        label_text = await get_label_text(page, input_el)
        if not label_text:
            continue
        lower = label_text.lower()
        if "experience" in lower and ("year" in lower or "yrs" in lower):
            skill = extract_skill_from_label(label_text)
            if not skill:
                continue
            years = "3" if skill.lower() in resume_lower else "1"
            await safe_fill(input_el, years)


async def handle_cover_letter_if_needed(page: Page, job_meta, resume_text: str, config: Config) -> None:
    textarea = page.locator(config.selectors.get("cover_letter_textarea", ""))
    if textarea and await textarea.count():
        job_description = job_meta.description or ""
        letter = generate_cover_letter(
            job_title=job_meta.title,
            company=job_meta.company,
            job_description=job_description,
            resume_text=resume_text,
            config=config,
        )
        await safe_fill(textarea.first, letter)


async def fill_by_placeholder(page: Page, placeholder: str, value: str) -> None:
    locator = page.locator(f"input[placeholder*='{placeholder}']")
    if await locator.count():
        await safe_fill(locator.first, value)


async def fill_by_label_contains(page: Page, fragment: str, value: str) -> None:
    labels = page.locator("label")
    count = await labels.count()
    for idx in range(count):
        label = labels.nth(idx)
        text = (await label.inner_text()).strip().lower()
        if fragment.lower() in text:
            control_id = await label.get_attribute("for")
            if control_id:
                input_el = page.locator(f"#{control_id}")
                if await input_el.count():
                    await safe_fill(input_el.first, value)


async def get_label_text(page: Page, input_el: Locator) -> Optional[str]:
    input_id = await input_el.get_attribute("id")
    if input_id:
        label = page.locator(f"label[for='{input_id}']")
        if await label.count():
            return (await label.first.inner_text()).strip()
    parent = input_el.locator("xpath=ancestor::label[1]")
    if await parent.count():
        return (await parent.first.inner_text()).strip()
    return None


def extract_skill_from_label(label: str) -> Optional[str]:
    match = re.search(r"with (.+)", label, re.IGNORECASE)
    if match:
        return match.group(1).strip()
    match = re.search(r"in (.+)", label, re.IGNORECASE)
    if match:
        return match.group(1).strip()
    return None


async def safe_fill(locator: Locator, value: str) -> None:
    await locator.fill("")
    await locator.type(str(value), delay=30)
