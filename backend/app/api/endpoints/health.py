from fastapi import APIRouter, status
from app.config import settings
from app.models.item import HealthResponse

router = APIRouter(tags=["Health"])


@router.get(
    "/health",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
)
def get_health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        version=settings.VERSION,
        environment=settings.ENVIRONMENT,
        color=settings.COLOR,
    )
