from datetime import datetime

from pydantic import BaseModel


class PostCreate(BaseModel):
    thread_id: int
    text: str
    country_code: str


class Post(BaseModel):
    id: int
    thread_id: int
    text: str
    country_code: str
    created_at: datetime
