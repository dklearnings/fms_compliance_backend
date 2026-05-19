from fastapi import FastAPI
from app.middleware.correlation import CorrelationIdMiddleware
from app.routers import drivers
from app.routers import activities
from app.routers import compliance
from app.routers import health

app = FastAPI(
    title="Fleet Compliance API",
    version="1.0.0"
)

app.add_middleware(CorrelationIdMiddleware)

app.include_router(drivers.router)
app.include_router(activities.router)
app.include_router(compliance.router)
app.include_router(health.router)