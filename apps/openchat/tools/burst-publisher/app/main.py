import os
import random
import string
import asyncio

import httpx

THREAD_URL = os.getenv("THREAD_URL", "http://thread-svc.openchat-dev/threads")
POST_URL = os.getenv("POST_URL", "http://post-svc.openchat-dev/posts")
COUNT = int(os.getenv("COUNT", "200"))
COUNTRY = os.getenv("COUNTRY", "IE")


def rand_text(n: int = 40) -> str:
    return "".join(random.choice(string.ascii_letters + " ") for _ in range(n))


async def main() -> None:
    async with httpx.AsyncClient(timeout=5.0) as client:
        r = await client.post(THREAD_URL, json={"topic": "burst", "country_code": COUNTRY})
        r.raise_for_status()
        thread_id = r.json()["id"]

        for _ in range(COUNT):
            rp = await client.post(
                POST_URL,
                json={
                    "thread_id": thread_id,
                    "text": rand_text(),
                    "country_code": COUNTRY,
                },
            )
            rp.raise_for_status()


if __name__ == "__main__":
    asyncio.run(main())
