---
description: FastAPI concurrency — async def vs def handler choice, never blocking the event loop, run_in_threadpool offload, and BackgroundTasks vs a real task queue.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- **Choose handler type by the official rule:** if the path operation function uses `await`-able (async) libraries, declare it `async def`; if it calls blocking (synchronous) libraries, declare it as a plain `def` so FastAPI runs it in an external thread pool automatically; when unsure, default to plain `def` — this is safer than a wrong `async def` that blocks the event loop ([async]).
- **Never block the event loop inside `async def`:** calling synchronous blocking I/O (database drivers without async support, `requests`, `time.sleep`, `open()` for large files) directly inside an `async def` handler stalls every other concurrent request on the same process ([async], [zk]).
- **Wrap unavoidable blocking calls with `run_in_threadpool`:** when you must call a synchronous function from within an `async def` context (e.g., a sync helper you cannot rewrite), use `starlette.concurrency.run_in_threadpool` to offload it to the thread pool and `await` the result ([zk]).
- **CPU-bound work belongs in a task queue or worker process:** CPU-intensive operations (image processing, ML inference, large data transforms) must not run in the event loop or even the I/O thread pool — they block threads and starve other requests; delegate to Celery, ARQ, or a subprocess ([zk]).
- **Use `BackgroundTasks` only for short, non-critical post-response work:** `BackgroundTasks` runs in the same process after the response is sent and provides no retry, persistence, or failure handling; it is appropriate for fire-and-forget notifications or lightweight audit writes, not for operations where failure matters ([bg]).
- **Promote to a real task queue when work is heavy, long-running, or must be retried:** Celery, ARQ, or equivalent queues provide durability, retries, monitoring, and worker isolation that `BackgroundTasks` cannot offer ([bg], [zk]).

## Common Mistakes

- Declaring a handler `async def` and calling a blocking driver (psycopg2, `requests`, `boto3` sync client, `time.sleep`) directly inside it — this freezes the entire event loop and kills concurrency ([async], [zk]).
- Using `BackgroundTasks` for critical work such as sending transactional emails, processing payments, or writing primary records — if the process restarts mid-task the work is silently lost ([bg], [zk]).
- Running CPU-bound computation (e.g., Pillow image resize, `pandas` aggregations) inside an `async def` handler — this blocks the event loop just as much as synchronous I/O ([zk]).
- Wrapping a CPU-bound function with `run_in_threadpool` — the GIL means threads do not parallelize Python CPU work; use a multiprocessing-based task queue instead ([zk]).
- Mixing `async def` and `def` handlers without understanding which thread context each runs in — `def` handlers run in a thread pool and may safely call blocking code; `async def` handlers run on the event loop and must not ([async]).

## Purpose

These rules ensure FastAPI applications stay responsive under concurrent load by preventing accidental event-loop blocking, correctly routing synchronous work to thread pools, and reserving `BackgroundTasks` for its intended lightweight use case. The handler-type choice (`async def` vs `def`) is FastAPI's primary concurrency lever and the single most common source of latency regressions in production deployments.

For language-level concerns (type annotations, PEP 8, general exception design, pytest basics) see `python/testing-unit.md` and `python/error-handling.md`.

## Rules

1. Choose handler type by the official rule: `async def` only when the function body `await`s async-native libraries; plain `def` for blocking libraries; plain `def` when unsure. ([async])
2. Never call blocking I/O or `time.sleep` inside an `async def` handler without `await`. ([async], [zk])
3. When you must invoke a synchronous function from an `async def` context, wrap it with `await run_in_threadpool(sync_fn, *args)`. ([zk])
4. Offload CPU-bound work to a task queue (Celery, ARQ) or worker process — do not use `run_in_threadpool` for CPU-bound code. ([zk])
5. Use `BackgroundTasks` only for short, non-critical, fire-and-forget work that tolerates silent failure on process restart; use a real task queue for anything that must be retried or audited. ([bg], [zk])

---

**Citation URLs**

- [async] https://fastapi.tiangolo.com/async/
- [bg] https://fastapi.tiangolo.com/tutorial/background-tasks/
- [zk] https://github.com/zhanymkanov/fastapi-best-practices
