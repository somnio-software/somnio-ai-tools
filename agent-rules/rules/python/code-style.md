---
description: Python code style — PEP 8 enforced via Ruff as CI gate; line length 88 (CONTESTED); naming conventions; 3-group sorted absolute imports; docstrings (PEP 257 + Google sections via Ruff D + convention=google, CONTESTED). Applies to all .py files.
globs: **/*.py
alwaysApply: false
---

## Best Practices

### Formatter and linter: Ruff as CI gate

Run Ruff for both linting and formatting (replaces flake8, isort, black, and pyupgrade). Ruff is configured in `pyproject.toml` under `[tool.ruff]`. The CI pipeline must fail on any lint or format violation.
Source: https://docs.astral.sh/ruff/ · https://docs.astral.sh/ruff/formatter/ · https://docs.astral.sh/ruff/settings/

```toml
# pyproject.toml
[tool.ruff]
line-length = 88  # CONTESTED — see note below
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "D"]

[tool.ruff.lint.pydocstyle]
convention = "google"  # CONTESTED — see note below

[tool.ruff.lint.isort]
force-sort-within-sections = false
known-first-party = ["<your_package>"]
```

**CONTESTED — line length 88:** PEP 8 (https://peps.python.org/pep-0008/) specifies 79 characters for code and 72 for docstrings. The Black formatter popularised 88 as a pragmatic increase; Ruff's formatter (https://docs.astral.sh/ruff/formatter/) defaults to 88. This project adopts **88** as the default for consistency with Ruff's formatter default, but teams may override it via `line-length` in `pyproject.toml`.

### Naming conventions (PEP 8)

Follow the naming rules from PEP 8 (https://peps.python.org/pep-0008/#naming-conventions):

- **Modules and packages:** `snake_case` (`my_module.py`, `my_package/`).
- **Functions, methods, variables, parameters:** `snake_case` (`parse_response`, `user_id`).
- **Classes:** `PascalCase` (`UserRepository`, `PaymentService`).
- **Constants (module-level, immutable):** `SCREAMING_SNAKE_CASE` (`MAX_RETRIES`, `DEFAULT_TIMEOUT`).
- **"Protected" members (single leading underscore):** `_internal`. Not enforced by the runtime, but signals "implementation detail".
- **Private name-mangled members (double leading underscore):** `__mangled`. Use sparingly; prefer `_single` in most cases.
- **Type variables:** Short `PascalCase` or single capital letter (`T`, `KT`, `VT`).

```python
# Good
MAX_RETRIES = 3

class UserRepository:
    def find_by_email(self, email: str) -> "User | None": ...

# Bad
maxRetries = 3

class userRepository:
    def FindByEmail(self, Email: str) -> "User | None": ...
```

### Imports: 3-group sorted absolute imports

Organise every file's imports into exactly three groups separated by a blank line. Never use relative imports at the package level; use absolute paths throughout.
Source: https://peps.python.org/pep-0008/#imports · https://docs.astral.sh/ruff/settings/ (isort rules)

```
Group 1 — stdlib:      import os, from pathlib import Path
Group 2 — third-party: import fastapi, from pydantic import BaseModel
Group 3 — first-party: from my_package.utils import helpers
```

Ruff's `I` rule set (isort) enforces this automatically. Do not write manual blank lines between imports within a group.

```python
# Good
import os
from pathlib import Path

import httpx
from pydantic import BaseModel

from my_package.config import Settings
from my_package.models import User

# Bad — mixed groups, relative import
from .models import User
import httpx
import os
from pydantic import BaseModel
```

### Docstrings: PEP 257 + Google style via Ruff D

Every public module, class, and function/method must have a docstring. Use the **one-liner form** for trivial cases; use the **multi-line Google-style form** when arguments, return values, or raised exceptions need documentation.

Sources:
- PEP 257 (conventions): https://peps.python.org/pep-0257/
- Google Python Style Guide (sections): https://google.github.io/styleguide/pyguide.html
- Ruff D rules with `convention = "google"`: https://docs.astral.sh/ruff/settings/

**CONTESTED — Google docstring convention:** PEP 257 (https://peps.python.org/pep-0257/) is the canonical standard and does not specify section format. Google style (https://google.github.io/styleguide/pyguide.html) and NumPy style are both widely adopted. This project adopts **Google style** (enforced via `ruff.lint.pydocstyle.convention = "google"`) because it is compact, readable, and natively supported by Ruff's `D` rule set. Teams preferring NumPy style must change the convention key and update this file.

```python
# One-liner (trivial functions)
def noop() -> None:
    """Do nothing."""

# Multi-line Google style
def parse_user(raw: dict) -> "User":
    """Parse a raw dictionary into a User domain object.

    Args:
        raw: Unvalidated mapping from an external source.

    Returns:
        A validated User instance.

    Raises:
        ValueError: If required fields are missing or invalid.
    """
    ...
```

Rules enforced by Ruff D + `convention = "google"`:
- Summary line on the first line, no leading blank line.
- Multi-line docstrings: blank line after summary, sections (`Args:`, `Returns:`, `Raises:`, `Attributes:`, `Example:`), closing `"""` on its own line.
- No trailing whitespace in docstrings.

---

## Common Mistakes

- **Mixing import groups or using relative imports** — Ruff isort (`I` rules) will flag this; fix it with `ruff check --fix`.
- **Line length over 88 with no `# noqa`** — Ruff formatter rewraps automatically; do not manually insert line breaks that contradict the formatter's output.
- **Missing docstring on a public function** — Ruff `D100`/`D101`/`D102`/`D103` will raise. Add a docstring rather than suppressing with `# noqa`.
- **Wrong docstring summary style** — e.g. "Returns the user" instead of an imperative "Return the user." Google style requires imperative mood.
- **`SCREAMING_SNAKE_CASE` used for mutable module-level objects** — constants are values that never change; a mutable list or dict must not use this casing.
- **Non-public names with double leading underscore where single underscore suffices** — `__private` triggers name mangling; use `_protected` unless you specifically need mangling in a class hierarchy.
- **Inline `# noqa` without a rule code** — always specify the suppressed code: `# noqa: E501`, never bare `# noqa`.
- **Docstring in `"""triple quotes"""` on same line as `def`** — only one-liners may keep the closing `"""` on the same line as the opening; multi-line docstrings must have `"""` on its own closing line.

---

## Purpose

Consistent code style reduces cognitive load during code review and onboarding by making every `.py` file look as if it were written by one person. Ruff as the single CI gate (lint + format + import sort) eliminates debates about formatting and ensures violations are caught before merge. Docstring conventions make inline documentation scannable and machine-readable for tools like Sphinx and IDEs.

---

## Rules

1. Ruff is the sole lint/format/import-sort gate; CI must run `ruff check` and `ruff format --check` and fail on any violation. (Source: https://docs.astral.sh/ruff/)
2. Configure Ruff in `pyproject.toml`; do not use `.ruffrc` or inline config files. (Source: https://docs.astral.sh/ruff/settings/)
3. Line length is **88** characters (CONTESTED: PEP 8 specifies 79; this project adopts 88 to match Ruff formatter default). (Source: https://docs.astral.sh/ruff/formatter/ · https://peps.python.org/pep-0008/)
4. Enable at minimum Ruff rule sets `E`, `F`, `W`, `I`, `D`; do not disable `E` or `F` rules project-wide. (Source: https://docs.astral.sh/ruff/settings/)
5. Modules and packages: `snake_case`. Functions, methods, variables, parameters: `snake_case`. Classes: `PascalCase`. Module-level immutable constants: `SCREAMING_SNAKE_CASE`. (Source: https://peps.python.org/pep-0008/#naming-conventions)
6. All imports must be absolute; never use relative imports outside of intra-package `__init__` re-exports. (Source: https://peps.python.org/pep-0008/#imports)
7. Imports are sorted into exactly 3 groups — stdlib, third-party, first-party — each separated by one blank line, enforced by Ruff isort (`I` rules). (Source: https://peps.python.org/pep-0008/#imports · https://docs.astral.sh/ruff/settings/)
8. Every public module, class, function, and method must have a docstring; omitting one is a Ruff `D1xx` violation. (Source: https://peps.python.org/pep-0257/)
9. Docstrings follow Google style (CONTESTED: PEP 257 is the baseline; NumPy style is an alternative; this project chooses Google for compactness) enforced via `ruff.lint.pydocstyle.convention = "google"`. (Source: https://peps.python.org/pep-0257/ · https://google.github.io/styleguide/pyguide.html · https://docs.astral.sh/ruff/settings/)
10. Multi-line docstring: summary on first line (imperative mood), blank line, sections (`Args:`, `Returns:`, `Raises:` as needed), closing `"""` on its own line. (Source: https://peps.python.org/pep-0257/ · https://google.github.io/styleguide/pyguide.html)
11. Use `# noqa: <CODE>` (never bare `# noqa`) to suppress a Ruff rule on a specific line, and add a brief comment explaining why. (Source: https://docs.astral.sh/ruff/settings/)
12. Do not use `SCREAMING_SNAKE_CASE` for mutable module-level objects; reserve it for truly immutable constants. (Source: https://peps.python.org/pep-0008/#naming-conventions)
