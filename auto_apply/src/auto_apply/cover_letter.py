from __future__ import annotations

import re
from typing import Dict, Iterable, List

from .utils import Config


def _tokenize(text: str) -> List[str]:
    return re.findall(r"[A-Za-z0-9#+.]+", text.lower())


def pick_overlap(job_description: str, resume_text: str, limit: int = 2) -> List[str]:
    job_tokens = set(_tokenize(job_description))
    resume_tokens = set(_tokenize(resume_text))
    overlap = [token for token in job_tokens if token in resume_tokens and len(token) > 3]
    return overlap[:limit]


def summarize_resume(resume_text: str, limit: int = 2) -> List[str]:
    sentences = [s.strip() for s in re.split(r"[\n\.]+", resume_text) if s.strip()]
    return sentences[:limit]


def generate_cover_letter(
    job_title: str,
    company: str,
    job_description: str,
    resume_text: str,
    config: Config,
) -> str:
    overlap = pick_overlap(job_description, resume_text)
    resume_points = summarize_resume(resume_text)

    lines: List[str] = []
    opening = f"I am excited to apply for the {job_title} role at {company}."
    lines.append(opening)

    if overlap:
        lines.append(
            "My background aligns with {} and {} mentioned in the JD.".format(
                overlap[0], overlap[1] if len(overlap) > 1 else "related priorities"
            )
        )

    if resume_points:
        lines.append(f"Recent impact: {resume_points[0]}")
        if len(resume_points) > 1:
            lines.append(f"I also bring {resume_points[1].lower()}.")

    closing = "I would value the chance to contribute from Melbourne right away."
    lines.append(closing)

    letter = " ".join(lines)

    words = letter.split()
    if len(words) > config.max_cover_letter_words:
        letter = " ".join(words[: config.max_cover_letter_words])
    return letter
