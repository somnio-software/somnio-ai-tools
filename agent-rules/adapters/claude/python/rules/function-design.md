### Python function design — single responsibility, early returns, pure functions, side-effect isolation, dataclasses, keyword-only args. Applies to all .py files.
> Applies to: `**/*.py`
## Rules

1. Each function has a single, clearly named responsibility — it either queries state or changes state, not both. (https://peps.python.org/pep-0020/)
2. Use guard clauses (early returns / raises) to handle preconditions before the happy path. Never nest the main logic inside an `else`. (https://peps.python.org/pep-0020/ — "Flat is better than nested.")
3. Keep pure computation separate from side effects. Business-logic functions must not perform I/O directly; receive collaborators via dependency injection instead. (https://arjancodes.com/blog/python-dependency-injection-best-practices/)
4. Never silently mutate a function argument. Return a new object or document mutation explicitly. (https://google.github.io/styleguide/pyguide.html)
5. Use `@dataclass` (or `@dataclass(frozen=True)`) for any group of fields that travels together as a unit; avoid bare `dict` or `tuple` for structured return values. (https://peps.python.org/pep-0557/)
6. Use `field(default_factory=...)` for mutable defaults inside dataclasses — never assign a mutable literal as a default. (https://peps.python.org/pep-0557/)
7. Mark flags, configuration, and non-obvious parameters as keyword-only using `*` in the function signature. (https://peps.python.org/pep-3102/)
8. Functions with more than ~20 lines of logic are a refactor signal. Extract a named helper rather than adding another indent level.
9. Side effects (logging, network, file I/O, DB writes) belong in clearly named boundary functions. Inject them as collaborators; do not import and call them inline inside domain logic. (https://snyk.io/blog/dependency-injection-python/)
10. Do not use `print` inside library/domain code. Accept a logger via dependency injection, or let the caller handle output. (https://google.github.io/styleguide/pyguide.html)

## Rules

### Single Responsibility
- Each function does **one thing**: it either queries state or changes state, not both. (Source: https://peps.python.org/pep-0020/ — "Simple is better than complex.")
- Functions longer than ~20 lines are a signal to extract a helper. Name the helper after *what* it does, not *how*.
- Side effects (I/O, mutation, network) are pushed to the edges; pure computation lives in the centre. (Source: https://google.github.io/styleguide/pyguide.html — functions section.)

### Early Returns ("Flat is Better Than Nested")
- Validate preconditions and return (or raise) early to keep the happy path un-indented. (Source: https://peps.python.org/pep-0020/ — "Flat is better than nested.")
- Avoid the "arrow anti-pattern" — deeply nested `if`/`else` chains that force readers to track 3+ levels of indentation simultaneously.

```python
# Good — guard clauses first, logic at top level
def process_order(order: Order) -> Receipt:
    if order is None:
        raise ValueError("order must not be None")
    if not order.items:
        raise ValueError("order must have at least one item")
    total = sum(item.price for item in order.items)
    return Receipt(order_id=order.id, total=total)

# Bad — logic buried inside nested else
def process_order(order: Order) -> Receipt:
    if order is not None:
        if order.items:
            total = sum(item.price for item in order.items)
            return Receipt(order_id=order.id, total=total)
        else:
            raise ValueError("order must have at least one item")
    else:
        raise ValueError("order must not be None")
```

### Pure Functions and Side-Effect Isolation
- A **pure function** always returns the same output for the same input and produces no observable side effects. Prefer pure functions for business logic. (Source: https://peps.python.org/pep-0020/ — "Explicit is better than implicit.")
- Isolate side effects (file I/O, database writes, HTTP calls, `print`) behind clearly named functions or service objects injected as dependencies. (Source: https://arjancodes.com/blog/python-dependency-injection-best-practices/ — dependency injection best practices.)
- Never mutate a mutable argument silently; return a new object or document the mutation explicitly. (Source: https://google.github.io/styleguide/pyguide.html.)

```python
# Good — pure computation, side effect isolated to caller
def compute_discount(price: float, rate: float) -> float:
    return round(price * (1 - rate), 2)

# Bad — hidden side effect inside business logic
def compute_discount(price: float, rate: float) -> float:
    result = round(price * (1 - rate), 2)
    print(f"Discount applied: {result}")  # side effect mixed in
    return result
```

### Dataclasses for Structured Data
- Use `@dataclass` (or `@dataclass(frozen=True)` for value objects) instead of plain dicts or tuples whenever a group of fields travels together. (Source: https://peps.python.org/pep-0557/ — Data Classes.)
- Frozen dataclasses express immutability at the type level and are hashable by default.
- For data that crosses service/API boundaries, prefer Pydantic models (see `data-validation.md`); for internal pure-Python structured data, `dataclass` is sufficient and has no runtime dependency.

```python
from dataclasses import dataclass, field

@dataclass(frozen=True)
class Money:
    amount: float
    currency: str

@dataclass
class OrderLine:
    product_id: str
    quantity: int
    unit_price: Money
    tags: list[str] = field(default_factory=list)
```

### Keyword-Only Arguments
- Mark parameters that are **not positional** with `*` in the signature. This prevents callers from passing arguments in the wrong order by accident. (Source: https://peps.python.org/pep-3102/ — Keyword-Only Arguments.)
- Use keyword-only args for boolean flags, optional configuration, and any parameter whose meaning is not obvious from its position.

```python
# Good — no risk of swapped positional args
def send_email(
    *,
    to: str,
    subject: str,
    body: str,
    html: bool = False,
) -> None: ...

# Bad — easy to swap positional args silently
def send_email(to: str, subject: str, body: str, html: bool = False) -> None: ...
```

- Avoid writing functions that both compute a result **and** write it to a file/database — split into two functions.
- Avoid arrow anti-pattern: three or more levels of nested `if`/`else` instead of early returns.
- Avoid returning `None` implicitly when the caller expects a value — missing `return` in some branches. (Source: https://google.github.io/styleguide/pyguide.html.)
- Avoid mutating a list or dict argument in-place without documenting it, causing unexpected caller-side changes.
- Avoid using positional-only boolean flags (`do_thing(True, False)`) — the call site is unreadable; use keyword-only args.
- Avoid using a plain `dict` as a function's return type when a `@dataclass` would make fields explicit and type-checkable.
- Avoid defining `default_factory` as a mutable literal (e.g., `field(default=[])`) — always use `field(default_factory=list)`. (Source: https://peps.python.org/pep-0557/.)
