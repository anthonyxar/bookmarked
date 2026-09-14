from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg2://bookmarked:bookmarked@db:5432/bookmarked"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 14  # 14 days
    cors_origins: list[str] = ["*"]

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
