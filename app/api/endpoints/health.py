from fastapi import APIRouter, status
from app.config import settings
from app.models.item import HealthResponse

router = APIRouter(tags=["Health"])


@router.get(
    "/health",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Health Check Probe",
    description="Endpoint for Docker, Load Balancers, and Blue-Green zero-downtime deployment verification",
)
def get_health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        version=settings.VERSION,
        environment=settings.ENVIRONMENT,
        color=settings.COLOR,
    )
