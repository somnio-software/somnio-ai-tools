---
description: Next.js Server Actions and Route Handlers for mutations — authenticate and authorize inside each one, validate input with a schema, return minimal results, useActionState for form state, revalidation after writes, and serverActions config.
globs: "app/**, src/app/**, src/actions/**, actions/**, src/data/**, src/lib/**"
alwaysApply: false
---

# Next.js Server Actions and Route Handlers

How to write mutations with Server Actions (`'use server'`) and HTTP endpoints with Route Handlers (`route.ts`) so that each one is a safe, validated, self-authorizing entry point.

## Purpose

Every exported Server Action is reachable with a direct POST request, and every Route Handler is a public HTTP endpoint, regardless of what UI renders them. A page-level auth check does not protect the actions it renders. Treat both as public API endpoints.

## Patterns

### Thin action, secure Data Access Layer

Keep `'use server'` files thin: parse input, delegate to a `server-only` Data Access Layer (DAL) function that authenticates, authorizes the specific resource, and writes. Then revalidate.

#### Good

```ts
// src/data/posts.ts
import 'server-only'
import { verifySession } from '@/data/auth'
import { db } from '@/lib/db'

export async function deletePost(postId: string) {
  const session = await verifySession()
  const post = await db.post.findUnique({ where: { id: postId }, select: { authorId: true } })
  if (!post || post.authorId !== session.userId) throw new Error('Forbidden')
  await db.post.delete({ where: { id: postId } })
}
```

```ts
// app/posts/actions.ts
'use server'

import { z } from 'zod'
import { updateTag } from 'next/cache'
import { deletePost } from '@/data/posts'

const DeletePostInput = z.object({ postId: z.string().uuid() })

export async function deletePostAction(input: unknown) {
  const { postId } = DeletePostInput.parse(input)
  await deletePost(postId)
  updateTag('posts')
}
```

#### Bad

```ts
// ❌ No auth, no ownership check, trusts the client-supplied object
'use server'

export async function deletePost(post: { id: string; authorId: string }) {
  await db.post.delete({ where: { id: post.id } })
}
```

---

### Validate every input with a schema

`FormData`, arguments, `params`, `searchParams`, headers and request bodies are untrusted. Validate shape and types with a schema library (Zod, Valibot, …) and return field errors instead of throwing for expected validation failures. Schema validation checks shape only; authorization is still required.

#### Good

```ts
// app/signup/actions.ts
'use server'

import { z } from 'zod'

const SignupSchema = z.object({
  email: z.email().trim(),
  password: z.string().min(12),
})

export type SignupState = { errors?: Record<string, string[]>; message?: string } | undefined

export async function signup(_prev: SignupState, formData: FormData): Promise<SignupState> {
  const parsed = SignupSchema.safeParse({
    email: formData.get('email'),
    password: formData.get('password'),
  })
  if (!parsed.success) {
    return { errors: z.flattenError(parsed.error).fieldErrors }
  }
  await createAccount(parsed.data)
  return { message: 'Check your inbox to confirm your account.' }
}
```

> Zod's error-flattening API differs between majors (`error.flatten()` vs `z.flattenError()` in Zod 4). Check the installed version.

#### Bad

```ts
// ❌ Casts instead of validating; any string (or null) reaches the database
'use server'

export async function updateProfile(formData: FormData) {
  await db.user.update({ where: { id: formData.get('id') as string }, data: { role: formData.get('role') as string } })
}
```

---

### Form state with `useActionState`

Use React's `useActionState(action, initialState)` in a Client Component to get `[state, formAction, pending]`. The action receives `(prevState, formData)`.

#### Good

```tsx
// app/signup/signup-form.tsx
'use client'

import { useActionState } from 'react'
import { signup } from './actions'

export function SignupForm() {
  const [state, formAction, pending] = useActionState(signup, undefined)
  return (
    <form action={formAction}>
      <input name="email" type="email" required />
      {state?.errors?.email && <p role="alert">{state.errors.email[0]}</p>}
      <input name="password" type="password" required />
      <button disabled={pending}>Sign up</button>
      {state?.message && <p>{state.message}</p>}
    </form>
  )
}
```

---

### Return minimal results

Action return values are serialized to the client. Return a status or a DTO, never raw database records.

#### Good

```ts
'use server'

export async function renameProject(projectId: string, name: string) {
  await renameProjectInDal(projectId, name)
  return { ok: true as const }
}
```

#### Bad

```ts
// ❌ Returns the whole row, including fields the client must not see
'use server'

export async function renameProject(projectId: string, name: string) {
  return db.project.update({ where: { id: projectId }, data: { name } })
}
```

---

### Revalidate after mutations

After a write, invalidate what changed. `updateTag(tag)` (Server Actions only) expires immediately for read-your-own-writes; `revalidateTag(tag, profile)` is stale-while-revalidate; `revalidatePath(path)` invalidates a route; `refresh()` re-renders the current route without invalidating the cache. `redirect()` throws, so call revalidation before it. See `data-fetching-caching.md`; these APIs differ by major.

#### Good

```ts
'use server'

import { updateTag } from 'next/cache'
import { redirect } from 'next/navigation'

export async function createPost(formData: FormData) {
  const post = await createPostInDal(parsePostForm(formData))
  updateTag('posts')
  redirect(`/posts/${post.id}`)
}
```

#### Bad

```ts
// ❌ redirect() throws, so the revalidation below never runs
redirect(`/posts/${post.id}`)
revalidatePath('/posts')
```

---

### Route Handlers are public endpoints too

`route.ts` handlers (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`) need the same authentication, authorization and validation as actions. Return 401 when unauthenticated, 403 when authenticated but not allowed. For webhooks, verify the provider's signature against the raw body before parsing.

#### Good

```ts
// app/api/projects/[id]/route.ts
import { z } from 'zod'
import { verifySessionOrNull } from '@/data/auth'
import { canEditProject, updateProject } from '@/data/projects'

const Body = z.object({ name: z.string().min(1).max(120) })

export async function PATCH(request: Request, ctx: RouteContext<'/api/projects/[id]'>) {
  const session = await verifySessionOrNull()
  if (!session) return new Response(null, { status: 401 })

  const { id } = await ctx.params
  if (!(await canEditProject(session.userId, id))) return new Response(null, { status: 403 })

  const parsed = Body.safeParse(await request.json().catch(() => null))
  if (!parsed.success) return Response.json({ errors: z.flattenError(parsed.error) }, { status: 400 })

  await updateProject(id, parsed.data)
  return new Response(null, { status: 204 })
}
```

#### Bad

```ts
// ❌ Relies on proxy.ts having checked the cookie; no ownership check; unvalidated body
export async function PATCH(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  await db.project.update({ where: { id }, data: await request.json() })
  return Response.json({ ok: true })
}
```

---

### Configuration and deployment

- Server Actions are POST-only and Next.js compares `Origin` with `Host`/`X-Forwarded-Host`. Behind a proxy or CDN with a different host, list trusted hosts in `serverActions.allowedOrigins`; never use a catch-all.
- Request bodies are capped at 1MB by default; raise `serverActions.bodySizeLimit` only for actions that need it, and validate size again in the action.
- The `serverActions` options live under `experimental` in current docs; check the installed version's `next.config` reference.
- When self-hosting on multiple instances, set a stable `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` so closure encryption and action IDs work across instances.
- The client dispatches Server Actions one at a time; do not use `Promise.all` over actions to parallelize. Parallelize inside one action instead.

## Best Practices

- Authenticate and authorize inside every Server Action and Route Handler, including authorization on the specific resource (prevent IDOR).
- Accept IDs plus the user's change; re-read ownership and other fields from a trusted source.
- Validate all input with a schema and return field errors for expected failures.
- Keep `'use server'` files thin and delegate to a `server-only` DAL.
- Return minimal, explicit results; never return ORM entities.
- Revalidate with tags (`updateTag`/`revalidateTag`) before `redirect()`.
- Add rate limiting to expensive or abuse-prone actions (sign-up, email sending, password reset).
- Use `useActionState` for form state and pending UI instead of hand-rolled fetch logic.

## Common Mistakes

- Assuming an action is private because it is not imported anywhere, or because the page that renders it checks auth.
- Relying on `proxy.ts`/`middleware.ts` for authorization of actions or Route Handlers.
- Accepting a full object from the client (including `id`, `ownerId`, `role`) and writing it as-is.
- Using `formData.get('x') as string` instead of validating.
- Returning database rows from actions.
- Calling `revalidatePath`/`updateTag` after `redirect()`.
- Using `updateTag` in a Route Handler (it is Server Actions only).
- Setting `serverActions.allowedOrigins` to overly broad wildcards.
- Mutating data during render (for example logging out on a `searchParams` flag) instead of in an action.
