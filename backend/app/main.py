from __future__ import annotations

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .models import ProcessRequest, ProcessResponse
from .processor import process_images

app = FastAPI(
    title="ImageMixer Local Dedup API",
    version="1.0.0",
    description="Local image deduplication API for Flutter desktop client.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/process-images", response_model=ProcessResponse)
def process_images_api(payload: ProcessRequest) -> ProcessResponse:
    try:
        return process_images(payload)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Process failed: {exc}") from exc
