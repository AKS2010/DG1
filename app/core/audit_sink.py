import asyncio
from datetime import UTC, datetime

from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobClient

from app.core.config import settings


class BlobAuditSink:
    def __init__(self) -> None:
        self._queue: asyncio.Queue[str] = asyncio.Queue(maxsize=10000)
        self._running = False
        self._task: asyncio.Task | None = None

    async def start(self) -> None:
        if not settings.azure_storage_account_url:
            return
        self._running = True
        self._task = asyncio.create_task(self._run())

    async def stop(self) -> None:
        self._running = False
        if self._task:
            await self._task

    async def enqueue(self, line: str) -> None:
        if not self._running:
            return
        try:
            self._queue.put_nowait(line)
        except asyncio.QueueFull:
            # Drop overflow logs to protect API latency.
            return

    async def _run(self) -> None:
        batch: list[str] = []
        while self._running or not self._queue.empty():
            try:
                item = await asyncio.wait_for(self._queue.get(), timeout=2.0)
                batch.append(item)
                if len(batch) >= 250:
                    await self._flush(batch)
                    batch = []
            except TimeoutError:
                if batch:
                    await self._flush(batch)
                    batch = []

    async def _flush(self, batch: list[str]) -> None:
        payload = ("\n".join(batch) + "\n").encode("utf-8")
        await asyncio.to_thread(self._append_blob, payload)

    def _append_blob(self, payload: bytes) -> None:
        now = datetime.now(UTC)
        path = (
            f"{now.year:04d}/{now.month:02d}/{now.day:02d}/{now.hour:02d}/"
            f"api-{now.strftime('%Y%m%d%H')}.ndjson"
        )
        credential = DefaultAzureCredential(exclude_interactive_browser_credential=True)
        client = BlobClient(
            account_url=settings.azure_storage_account_url,
            container_name=settings.azure_storage_container,
            blob_name=path,
            credential=credential,
        )
        if not client.exists():
            client.create_append_blob()
        client.append_block(payload)
