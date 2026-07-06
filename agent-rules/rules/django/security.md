---
description: Django security hardening — CSRF, template XSS/autoescape, ORM vs raw SQL, clickjacking, HTTPS/HSTS/secure cookies, host header validation, upload hardening, CSP. Applies to all Python files in a Django project.
globs: **/*.py
alwaysApply: false
---

## Best Practices

- **Keep `CsrfViewMiddleware` enabled at all times.** CSRF protection is on by default; never disable it globally and avoid `@csrf_exempt` on real endpoints. For legitimate AJAX use cases, pass the token via the `X-CSRFToken` header rather than exempting the view. ([Django security topic](https://docs.djangoproject.com/en/stable/topics/security/))
- **Rely on Django's template autoescaping.** The template engine escapes HTML entities automatically; never pass user-controlled content through `mark_safe()`, the `|safe` filter, or `format_html()` with unsanitized arguments. When `format_html()` is required, wrap every user value with `format_html("{}", value)` so it is escaped. ([Django security topic](https://docs.djangoproject.com/en/stable/topics/security/))
- **Use the ORM or parameterized queries for all database access.** Never interpolate Python variables directly into `.raw()`, `.extra()`, or `RawSQL()` calls. When raw SQL is unavoidable, use the `params` argument: `Model.objects.raw("SELECT … WHERE id = %s", [user_id])`. ([Django security topic](https://docs.djangoproject.com/en/stable/topics/security/))
- **Keep `XFrameOptionsMiddleware` enabled** to prevent clickjacking. The default `DENY` policy blocks all framing; use `SAMEORIGIN` only when you own the framing page. ([Django security topic](https://docs.djangoproject.com/en/stable/topics/security/))
- **Enforce HTTPS in production:** set `SECURE_SSL_REDIRECT = True`, `SESSION_COOKIE_SECURE = True`, `CSRF_COOKIE_SECURE = True`, and configure HSTS via `SECURE_HSTS_SECONDS` (minimum 31536000), `SECURE_HSTS_INCLUDE_SUBDOMAINS = True`, and `SECURE_HSTS_PRELOAD = True`. ([Django deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))
- **Validate the `Host` header through `ALLOWED_HOSTS`.** Never read `request.META['HTTP_HOST']` directly for security decisions; always use `request.get_host()`, which validates against `ALLOWED_HOSTS`. ([Django deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))
- **Enforce authentication and authorization using Django's auth system and DRF permission/throttling classes.** Add throttling to authentication endpoints (`AnonRateThrottle`) to mitigate brute-force attacks. ([Django security topic](https://docs.djangoproject.com/en/stable/topics/security/))
- **Harden file uploads:** serve user-uploaded media from a separate domain (or a dedicated CDN) so scripts in uploaded files cannot access session cookies on your app domain; restrict accepted MIME types and file sizes at the application layer; never execute or shell-out to uploaded files. ([Django security topic](https://docs.djangoproject.com/en/stable/topics/security/))
- **Configure a Content Security Policy.** Django 6.0+ ships `django.middleware.csp.ContentSecurityPolicyMiddleware` with `CONTENT_SECURITY_POLICY` settings; for earlier versions use `django-csp`. A restrictive CSP is a critical defence-in-depth layer even when autoescape is on. ([Django deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))

## Common Mistakes

- Applying `@csrf_exempt` to endpoints that process state-changing operations (login, purchase, profile update) because "the client sends JSON" — CSRF applies to any cookie-authenticated request regardless of content-type.
- Calling `mark_safe(user_input)` or rendering `{{ variable|safe }}` where `variable` contains user-controlled content, introducing stored or reflected XSS.
- Building raw SQL with f-strings or `%` string formatting instead of the `params` argument, enabling SQL injection even through Django's ORM escape layer.
- Reading `request.META['HTTP_HOST']` directly for redirects or URL generation, allowing host-header injection attacks.
- Omitting `SESSION_COOKIE_SECURE` or `CSRF_COOKIE_SECURE` in production, exposing session tokens over plain HTTP on mixed-content pages.
- Setting `SECURE_HSTS_SECONDS` to a very short value (or 0) in production, negating HSTS protection.
- Serving media files from the same domain as the application, allowing an attacker who uploads an HTML file to steal cookies via XSS.
- Leaving authentication endpoints un-throttled, making brute-force credential stuffing trivial.

## Purpose

Django ships with strong security defaults — CSRF middleware, template autoescaping, `ALLOWED_HOSTS` validation, and `XFrameOptionsMiddleware` — but each default can be accidentally disabled or bypassed. This rule set keeps those defaults intact, extends them to HTTPS/HSTS, tightens host and upload handling, and mandates a CSP layer. Deployment-time configuration concerns (setting `DEBUG=False`, splitting settings files, `SECRET_KEY` rotation) are covered in `settings-config.md`; generic Python exception design is covered in `python/error-handling.md`.

## Rules

1. Never apply `@csrf_exempt` to a state-changing endpoint. Pass the CSRF token in the `X-CSRFToken` request header for AJAX clients instead of disabling protection. ([Django security topic](https://docs.djangoproject.com/en/stable/topics/security/))
2. Never pass user-controlled data to `mark_safe()`, `|safe`, or as unescaped arguments to `format_html()`. All user values rendered in templates must be auto-escaped or explicitly escaped with `format_html("{}", value)`. ([Django security topic](https://docs.djangoproject.com/en/stable/topics/security/))
3. Never interpolate Python variables into `.raw()`, `.extra()`, or `RawSQL()` strings. Always supply user-controlled values through the `params` argument. ([Django security topic](https://docs.djangoproject.com/en/stable/topics/security/))
4. Keep `XFrameOptionsMiddleware` enabled. Use `X_FRAME_OPTIONS = 'DENY'` (the default) unless the same-origin framing case is explicitly required and documented. ([Django security topic](https://docs.djangoproject.com/en/stable/topics/security/))
5. In production, set `SECURE_SSL_REDIRECT = True`, `SESSION_COOKIE_SECURE = True`, and `CSRF_COOKIE_SECURE = True`. ([Django deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))
6. Configure HSTS: `SECURE_HSTS_SECONDS >= 31536000`, `SECURE_HSTS_INCLUDE_SUBDOMAINS = True`, `SECURE_HSTS_PRELOAD = True`. Start with a short value in staging to verify no HTTP-only sub-resources exist, then raise to a full year for production. ([Django deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))
7. Never read `request.META['HTTP_HOST']` for security decisions. Use `request.get_host()`, which validates against `ALLOWED_HOSTS`. ([Django deployment checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/))
8. Apply DRF throttle classes (e.g. `AnonRateThrottle`, `UserRateThrottle`) to all authentication and sensitive endpoints to mitigate brute-force attacks. ([Django security topic](https://docs.djangoproject.com/en/stable/topics/security/))
9. Serve user-uploaded media from a domain that is not the application's session-cookie domain (separate CDN or subdomain with `SESSION_COOKIE_DOMAIN` scoped appropriately). Restrict accepted MIME types and maximum file sizes at the application layer. Never execute uploaded files. ([Django security topic](https://docs.djangoproject.com/en/stable/topics/security/))
