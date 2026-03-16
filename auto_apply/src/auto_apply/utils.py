import argparse
import json
import random
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field, validator


class PauseWindow(BaseModel):
    min_seconds: float = Field(default=3.0, gt=0)
    max_seconds: float = Field(default=8.0, gt=0)

    @validator("max_seconds")
    def validate_range(cls, v, values):  # type: ignore[override]
        min_v = values.get("min_seconds", 0)
        if v < min_v:
            raise ValueError("max_seconds must be >= min_seconds")
        return v

    def jitter(self) -> float:
        return random.uniform(self.min_seconds, self.max_seconds)


class Config(BaseModel):
    search_keywords: List[str]
    applications_per_run: int = 10
    runs_per_day: int = 3
    location_preference: str
    phone_number: str
    min_salary: int
    default_salary: int
    salary_currency: str = "AUD"
    standard_answers: Dict[str, str]
    resume_context_path: str
    cookies_path: str
    cv_name_on_linkedin: str
    logging_dir: str = "logs"
    max_cover_letter_words: int = 100
    dry_run: bool = False
    pause_between_actions: PauseWindow = PauseWindow()
    selectors: Dict[str, str]
    headless: bool = True

    @validator("search_keywords")
    def non_empty_keywords(cls, v):  # type: ignore[override]
        if not v:
            raise ValueError("At least one search keyword is required")
        return v


class ResourceBundle(BaseModel):
    config: Config
    resume_text: str
    cookies: List[Dict[str, Any]]


def load_config(path: Path) -> Config:
    data = json.loads(path.read_text())
    return Config(**data)


def load_resume_text(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"Resume context file not found: {path}")
    return path.read_text(encoding="utf-8")


def load_cookies(path: Path) -> List[Dict[str, Any]]:
    if not path.exists():
        raise FileNotFoundError(
            "LinkedIn cookies file missing. Export cookies and save to cookies.json"
        )
    return json.loads(path.read_text())


def ensure_logging_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def make_logger(log_root: Path):
    ensure_logging_dir(log_root)
    log_path = log_root / f"applications-{datetime.now().date()}.jsonl"

    def log(entry: Dict[str, Any]):
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry, ensure_ascii=False) + "\n")

    return log


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="LinkedIn Easy Apply automation")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("config.json"),
        help="Path to config JSON",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Walk through the flow without hitting Submit",
    )
    head_group = parser.add_mutually_exclusive_group()
    parser.set_defaults(headless=None)
    head_group.add_argument(
        "--headed",
        action="store_false",
        dest="headless",
        help="Run browser with UI",
    )
    head_group.add_argument(
        "--headless",
        action="store_true",
        dest="headless",
        help="Run browser headless (default)",
    )
    return parser.parse_args()


def build_resources(config_path: Path, dry_run_flag: Optional[bool], headless_override: Optional[bool]) -> ResourceBundle:
    config = load_config(config_path)
    if dry_run_flag is not None:
        config.dry_run = dry_run_flag
    if headless_override is not None:
        config.headless = headless_override

    resume_text = load_resume_text(Path(config.resume_context_path))
    cookies = load_cookies(Path(config.cookies_path))

    return ResourceBundle(config=config, resume_text=resume_text, cookies=cookies)
