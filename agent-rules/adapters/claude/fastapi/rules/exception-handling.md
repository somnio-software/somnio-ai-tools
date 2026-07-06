### FastAPI exception handling — raise HTTPException, centralized app exception handlers, overriding Starlette HTTPException, and translating domain errors to HTTP at the boundary. Layers on the python stack's error-handling rules.
> Applies to: `**/*.py`
## Rules

1. Always `raise HTTPException(status_code=..., detail=...)` — never assign it to a variable and return it.
2. Translate domain exceptions to HTTP responses in a centralized `@app.exception_handler` registration, not via per-route `try/except` blocks.
3. Register exception handlers against Starlette's `HTTPException` (`from starlette.exceptions import HTTPException`) so middleware and internal framework errors are captured alongside application errors.
4. Override `RequestValidationError` with a custom handler that returns a 4xx response; never allow Pydantic validation failures to surface as 500s.
5. Define per-domain exception classes in each domain's `exceptions.py` and raise `HTTPException` (or let a registered handler translate) only at the HTTP boundary — service and repository code must not import from `fastapi` or `starlette`.
6. When adding logging to a default handler, `await` the original FastAPI/Starlette default handler from within your override rather than reimplementing response construction.

## Rules

- Always `raise HTTPException(status_code=..., detail=..., headers=...)` — never `return` an `HTTPException` instance. Returning it produces a 200 response with the exception object as the body; only raising it activates FastAPI's error machinery. ([errors](https://fastapi.tiangolo.com/tutorial/handling-errors/))
- Register centralized exception handlers with `@app.exception_handler(MyDomainError)` to translate domain exceptions to HTTP responses in one place rather than scattering `try/except` across route handlers. ([errors](https://fastapi.tiangolo.com/tutorial/handling-errors/))
- When overriding the built-in `HTTPException` handler, register against **Starlette's** `HTTPException` (`from starlette.exceptions import HTTPException`) — not FastAPI's re-export — so that errors raised internally by middleware and Starlette itself are also captured. ([errors](https://fastapi.tiangolo.com/tutorial/handling-errors/))
- Override `RequestValidationError` with a custom `@app.exception_handler(RequestValidationError)` to control the shape of 422 responses; never let validation errors fall through to a 500. ([errors](https://fastapi.tiangolo.com/tutorial/handling-errors/))
- Inside a custom exception handler that replaces a default FastAPI handler, `await` the original default handler (e.g. `await http_exception_handler(request, exc)`) when you only need to add logging — this keeps the default behavior while adding observability without duplicating response-building logic. ([errors](https://fastapi.tiangolo.com/tutorial/handling-errors/))
- Define per-domain exception classes (e.g. `ItemNotFoundError`, `InsufficientFundsError`) in each domain's `exceptions.py` and translate them to `HTTPException` at the router/handler boundary, not deep inside service or repository code. ([zk](https://github.com/zhanymkanov/fastapi-best-practices))
- For language-level exception design (custom exception hierarchies, EAFP, never swallowing), see `python/error-handling.md`.

- Avoid `return HTTPException(status_code=404, detail="Not found")` instead of `raise`: the response status is 200 and the body is a serialized exception object; FastAPI's error handler is never invoked. ([errors](https://fastapi.tiangolo.com/tutorial/handling-errors/))
- Avoid scattered per-route `try/except` blocks that build `JSONResponse` directly: produces inconsistent error shapes across endpoints and prevents centralized logging or monitoring. ([errors](https://fastapi.tiangolo.com/tutorial/handling-errors/))
- Avoid overriding only FastAPI's `HTTPException` (imported from `fastapi`) and missing Starlette's: internal framework errors and middleware exceptions bypass the custom handler and may return an unexpected response format. ([errors](https://fastapi.tiangolo.com/tutorial/handling-errors/))
- Avoid letting `RequestValidationError` fall through without a handler: Pydantic validation failures return a 422 by default, but without a handler you cannot customize the response shape, add structured logging, or map field errors to a client-friendly format — and misconfigurations can surface as 500s. ([errors](https://fastapi.tiangolo.com/tutorial/handling-errors/))
- Avoid raising `HTTPException` deep inside a service or repository function: couples business logic to the HTTP layer, breaks reusability, and makes unit-testing services without a running app difficult. ([zk](https://github.com/zhanymkanov/fastapi-best-practices))
