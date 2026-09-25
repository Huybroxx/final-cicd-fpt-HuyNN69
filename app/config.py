from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    PROJECT_NAME: str = Field(default="FastAPI DevOps Service", description="Project name")
    VERSION: str = Field(default="1.0.0", description="Application version")
    API_V1_STR: str = Field(default="/api/v1", description="API v1 prefix")
    ENVIRONMENT: str = Field(default="production", description="Runtime environment")
    DEBUG: bool = Field(default=False, description="Debug flag")
    HOST: str = Field(default="0.0.0.0", description="Server host")
    PORT: int = Field(default=8000, description="Server port")
    COLOR: str = Field(default="blue", description="Active deployment color: blue or green")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


settings = Settings()
