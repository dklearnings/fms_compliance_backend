from fastapi import FastAPI
from middleware.correlation import CorrelationIdMiddleware
from routers import drivers, activities, compliance, health


app = FastAPI(
    title="Fleet Compliance API",
    version="1.0.0"
)

app.add_middleware(CorrelationIdMiddleware)

@app.get("/")
def read_root():
    return {"message": "Welcome to the Fleet Compliance API!"}

app.include_router(drivers.router)
app.include_router(activities.router)
app.include_router(compliance.router)
app.include_router(health.router)

