from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


"""
Backend API models.

Deduplication/rollback/report models have been removed intentionally.
"""


class ProcessRequest(BaseModel):
    input_dir: str
    output_dir: str
    recursive: bool = True
    max_workers: int = Field(0, ge=0, le=64, description="0 means auto")
    preset: Literal["invisible", "mild", "standard", "strong"] = "invisible"
    output_format: Literal["jpg", "png", "webp", "keep"] = "keep"
    seed: int | None = None
    custom_enabled: bool = True

    # Custom pipeline switches + params (defaults are "invisible" settings)
    enable_crop: bool = True
    crop_ratio: float = Field(0.995, ge=0.5, le=1.0)

    enable_rotate: bool = True
    rotate_deg: float = Field(0.2, ge=0.0, le=5.0)

    enable_resize: bool = True
    max_size: int = Field(6000, ge=256, le=12000)

    enable_zoom: bool = True
    zoom_factor: float = Field(1.01, ge=1.0, le=1.2)

    enable_color: bool = True
    brightness: float = Field(0.01, ge=0.0, le=0.2)
    contrast: float = Field(0.01, ge=0.0, le=0.2)
    saturation: float = Field(0.01, ge=0.0, le=0.2)

    enable_noise: bool = True
    noise_sigma: float = Field(0.3, ge=0.0, le=8.0)

    enable_compress: bool = True
    jpeg_quality: int = Field(97, ge=60, le=100)

    enable_exif: bool = True


class ProcessStats(BaseModel):
    input_dir: str
    output_dir: str
    total_files: int
    processed_files: int
    failed_files: int
    elapsed_seconds: float


class ProcessResponse(BaseModel):
    stats: ProcessStats
    failed_samples: list[str] = []
