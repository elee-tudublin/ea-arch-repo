from pydantic import BaseModel


class ThreadCreate(BaseModel):
    topic: str
    country_code: str


class Thread(BaseModel):
    id: int
    topic: str
    country_code: str
