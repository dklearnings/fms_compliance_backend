from pydantic import BaseModel
from uuid import UUID

class CreateDriverRequest(BaseModel):
    full_name: str
    license_number: str
    card_number: str


class CreateDriverResponse(BaseModel):
    driver_id: UUID