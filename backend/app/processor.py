from __future__ import annotations

import os
import random
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFile

try:
    from pillow_heif import register_heif_opener

    register_heif_opener()
    HEIF_SUPPORTED = True
except Exception:
    HEIF_SUPPORTED = False

from .models import ProcessRequest, ProcessResponse, ProcessStats

ImageFile.LOAD_TRUNCATED_IMAGES = True

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tif", ".tiff", ".heic", ".heif"}
if not HEIF_SUPPORTED:
    IMAGE_EXTENSIONS.discard(".heic")
    IMAGE_EXTENSIONS.discard(".heif")


def _list_images(input_dir: Path, recursive: bool) -> list[Path]:
    iterator = input_dir.rglob("*") if recursive else input_dir.glob("*")
    return [path for path in iterator if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS]


def _preset_params(name: str) -> dict:
    if name == "invisible":
        return {
            "crop_ratio": 0.995,
            "rotate_deg": 0.2,
            "max_size": 6000,
            "zoom_factor": 1.01,
            "brightness": 0.01,
            "contrast": 0.01,
            "saturation": 0.01,
            "noise_sigma": 0.3,
            "jpeg_quality": 97,
        }
    if name == "mild":
        return {
            "crop_ratio": 0.985,
            "rotate_deg": 0.6,
            "max_size": 2400,
            "zoom_factor": 1.02,
            "brightness": 0.02,
            "contrast": 0.02,
            "saturation": 0.02,
            "noise_sigma": 0.8,
            "jpeg_quality": 94,
        }
    if name == "strong":
        return {
            "crop_ratio": 0.92,
            "rotate_deg": 3.0,
            "max_size": 1400,
            "zoom_factor": 1.05,
            "brightness": 0.08,
            "contrast": 0.08,
            "saturation": 0.08,
            "noise_sigma": 5.0,
            "jpeg_quality": 80,
        }
    return {
        "crop_ratio": 0.95,
        "rotate_deg": 2.0,
        "max_size": 1600,
        "zoom_factor": 1.03,
        "brightness": 0.05,
        "contrast": 0.05,
        "saturation": 0.05,
        "noise_sigma": 3.0,
        "jpeg_quality": 85,
    }


def _split_rgba(image: Image.Image) -> tuple[Image.Image, Image.Image | None]:
    if image.mode in ("RGBA", "LA") or ("transparency" in image.info):
        rgba = image.convert("RGBA")
        alpha = rgba.split()[-1]
        rgb = rgba.convert("RGB")
        return rgb, alpha
    return image.convert("RGB"), None


def _merge_rgba(rgb: Image.Image, alpha: Image.Image | None) -> Image.Image:
    if alpha is None:
        return rgb
    rgba = rgb.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba


def _apply_pipeline(image: Image.Image, rng: random.Random, params: dict) -> Image.Image:
    rgb, alpha = _split_rgba(image)
    width, height = rgb.size

    if params.get("enable_crop", True):
        crop_ratio = params["crop_ratio"]
        if 0.0 < crop_ratio < 1.0:
            new_w = max(1, int(width * crop_ratio))
            new_h = max(1, int(height * crop_ratio))
            if new_w < width or new_h < height:
                left = max(0, (width - new_w) // 2)
                top = max(0, (height - new_h) // 2)
                rgb = rgb.crop((left, top, left + new_w, top + new_h))
                if alpha is not None:
                    alpha = alpha.crop((left, top, left + new_w, top + new_h))

    if params.get("enable_rotate", True):
        rotate_deg = params["rotate_deg"]
        if rotate_deg > 0:
            angle = rng.uniform(-rotate_deg, rotate_deg)
            rgb = rgb.rotate(angle, resample=Image.BICUBIC, expand=False, fillcolor=(0, 0, 0))
            if alpha is not None:
                alpha = alpha.rotate(angle, resample=Image.BICUBIC, expand=False, fillcolor=0)

    if params.get("enable_zoom", True):
        zoom_factor = params.get("zoom_factor", 1.0)
        if zoom_factor > 1.0:
            w, h = rgb.size
            new_w = max(1, int(w * zoom_factor))
            new_h = max(1, int(h * zoom_factor))
            zoomed = rgb.resize((new_w, new_h), Image.LANCZOS)
            left = max(0, (new_w - w) // 2)
            top = max(0, (new_h - h) // 2)
            rgb = zoomed.crop((left, top, left + w, top + h))
            if alpha is not None:
                zoomed_a = alpha.resize((new_w, new_h), Image.LANCZOS)
                alpha = zoomed_a.crop((left, top, left + w, top + h))

    if params.get("enable_resize", True):
        max_size = params["max_size"]
        if max_size > 0:
            w, h = rgb.size
            if max(w, h) > max_size:
                scale = max_size / float(max(w, h))
                rgb = rgb.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
                if alpha is not None:
                    alpha = alpha.resize((int(w * scale), int(h * scale)), Image.LANCZOS)

    if params.get("enable_color", True):
        brightness = params["brightness"]
        if brightness > 0:
            rgb = ImageEnhance.Brightness(rgb).enhance(
                1.0 + rng.uniform(-brightness, brightness)
            )
        contrast = params["contrast"]
        if contrast > 0:
            rgb = ImageEnhance.Contrast(rgb).enhance(
                1.0 + rng.uniform(-contrast, contrast)
            )
        saturation = params["saturation"]
        if saturation > 0:
            rgb = ImageEnhance.Color(rgb).enhance(
                1.0 + rng.uniform(-saturation, saturation)
            )

    if params.get("enable_noise", True):
        noise_sigma = params["noise_sigma"]
        if noise_sigma > 0:
            arr = np.asarray(rgb).astype(np.float32)
            seed = rng.randint(0, 2**31 - 1)
            local_rng = np.random.default_rng(seed)
            arr += local_rng.normal(0, noise_sigma, size=arr.shape)
            arr = np.clip(arr, 0, 255).astype(np.uint8)
            rgb = Image.fromarray(arr, mode="RGB")

    return _merge_rgba(rgb, alpha)


def _update_exif(exif, rng: random.Random) -> None:
    # Update a few common EXIF tags if available.
    now = time.strftime("%Y:%m:%d %H:%M:%S")
    shift_days = rng.randint(-7, 7)
    shift_seconds = shift_days * 86400
    shifted = time.strftime("%Y:%m:%d %H:%M:%S", time.localtime(time.time() + shift_seconds))
    exif[306] = now
    exif[36867] = shifted
    exif[36868] = shifted
    exif[271] = "ImageMixer"
    exif[272] = f"Mix-{rng.randint(1000, 9999)}"
    exif[305] = "ImageMixer"


def _resolve_output_path(
    input_path: Path, input_dir: Path, output_dir: Path, fmt: str
) -> tuple[Path, str]:
    rel_path = input_path.relative_to(input_dir)
    if fmt == "keep":
        suffix = input_path.suffix.lower().lstrip(".")
        if suffix in ("jpg", "jpeg"):
            return output_dir / rel_path, "jpg"
        if suffix in ("png", "webp", "bmp", "tif", "tiff"):
            return output_dir / rel_path, suffix
        return (output_dir / rel_path).with_suffix(".png"), "png"
    suffix = f".{fmt}"
    return (output_dir / rel_path).with_suffix(suffix), fmt


def _process_one(
    path: Path,
    input_dir: Path,
    output_dir: Path,
    fmt: str,
    params: dict,
    seed: int | None,
) -> tuple[bool, str | None]:
    try:
        with Image.open(path) as img:
            rng = random.Random((seed or 0) + hash(path.as_posix()))
            image = _apply_pipeline(img, rng, params)
            exif = img.getexif()

            output_path, target_format = _resolve_output_path(path, input_dir, output_dir, fmt)
            output_path.parent.mkdir(parents=True, exist_ok=True)

            save_params = {}
            if params.get("enable_compress", True):
                if target_format == "jpg":
                    save_params = {"quality": params["jpeg_quality"], "optimize": True}
                elif target_format == "webp":
                    save_params = {"quality": params["jpeg_quality"]}

            exif_bytes = None
            if exif and params.get("enable_exif", True) and target_format in ("jpg", "webp", "tiff"):
                _update_exif(exif, rng)
                exif_bytes = exif.tobytes()

            if target_format == "jpg":
                if image.mode in ("RGBA", "LA"):
                    background = Image.new("RGB", image.size, (255, 255, 255))
                    image = Image.alpha_composite(background.convert("RGBA"), image).convert("RGB")
                else:
                    image = image.convert("RGB")
            save_kwargs = dict(save_params)
            if exif_bytes is not None:
                save_kwargs["exif"] = exif_bytes
            image.save(output_path, **save_kwargs)
        return True, None
    except Exception as exc:
        return False, f"{path}: {exc}"


def _resolve_params(request: ProcessRequest) -> dict:
    if not request.custom_enabled:
        params = _preset_params(request.preset)
        params.update(
            {
                "enable_crop": True,
                "enable_rotate": True,
                "enable_resize": True,
                "enable_zoom": True,
                "enable_color": True,
                "enable_noise": True,
                "enable_compress": True,
                "enable_exif": True,
            }
        )
        return params

    return {
        "enable_crop": request.enable_crop,
        "crop_ratio": request.crop_ratio,
        "enable_rotate": request.enable_rotate,
        "rotate_deg": request.rotate_deg,
        "enable_resize": request.enable_resize,
        "max_size": request.max_size,
        "enable_zoom": request.enable_zoom,
        "zoom_factor": request.zoom_factor,
        "enable_color": request.enable_color,
        "brightness": request.brightness,
        "contrast": request.contrast,
        "saturation": request.saturation,
        "enable_noise": request.enable_noise,
        "noise_sigma": request.noise_sigma,
        "enable_compress": request.enable_compress,
        "jpeg_quality": request.jpeg_quality,
        "enable_exif": request.enable_exif,
    }


def process_images(request: ProcessRequest) -> ProcessResponse:
    started_at = time.perf_counter()
    input_dir = Path(request.input_dir).expanduser().resolve()
    output_dir = Path(request.output_dir).expanduser().resolve()
    if not input_dir.exists() or not input_dir.is_dir():
        raise ValueError(f"input_dir does not exist or is not a directory: {input_dir}")
    output_dir.mkdir(parents=True, exist_ok=True)

    images = _list_images(input_dir, request.recursive)
    params = _resolve_params(request)

    workers = request.max_workers if request.max_workers > 0 else max(2, min(16, (os.cpu_count() or 4)))
    processed = 0
    failed = 0
    failed_samples: list[str] = []

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [
            executor.submit(
                _process_one,
                path,
                input_dir,
                output_dir,
                request.output_format,
                params,
                request.seed,
            )
            for path in images
        ]
        for future in as_completed(futures):
            ok, err = future.result()
            if ok:
                processed += 1
            else:
                failed += 1
                if err and len(failed_samples) < 10:
                    failed_samples.append(err)

    elapsed = round(time.perf_counter() - started_at, 3)
    stats = ProcessStats(
        input_dir=str(input_dir),
        output_dir=str(output_dir),
        total_files=len(images),
        processed_files=processed,
        failed_files=failed,
        elapsed_seconds=elapsed,
    )
    return ProcessResponse(stats=stats, failed_samples=failed_samples)
