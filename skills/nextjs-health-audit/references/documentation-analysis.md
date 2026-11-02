# Next.js Documentation Analysis

> Review technical documentation, environment setup instructions, component documentation (Storybook), architecture notes and agent-facing documentation for a Next.js project.

---

Goal: Review all technical documentation in the Next.js project to
evaluate documentation completeness and developer experience quality.

ANALYSIS TARGETS:

1. **README Quality**:
   - Check `README.md` exists in the project root (and per app in a
     monorepo)
   - Flag the untouched `create-next-app` README ("This is a Next.js
     project bootstrapped with create-next-app ...") as minimal
   - Verify README contains:
     * Project description
     * Prerequisites (Node.js version / `.nvmrc`, package manager — and
       `corepack enable` when pnpm or yarn is pinned)
     * Installation instructions with the repo's package manager
       (`pnpm install`)
     * Development server (`pnpm dev`)
     * Test instructions (unit and E2E)
     * Build and start (`pnpm build`, `pnpm start`)
     * Environment variable setup (`.env.example` → `.env.local`)
     * Deployment notes (target platform, `output` mode) — presence only
   - Note missing sections

2. **Environment Setup Documentation**:
   - `.env.example` / `.env.template` present and covering every
     variable referenced in code (`process.env.X`) — sample-compare
   - Which variables are `NEXT_PUBLIC_` (client-exposed) is documented
   - Purpose of each variable documented inline
   - `.env*.local` gitignored

3. **Storybook** (component documentation):
   - `.storybook/` and `@storybook/nextjs` / `@storybook/nextjs-vite`
   - Count `*.stories.tsx` files
   - Storybook built or tested in CI
   - Storybook is optional, but a strong signal for mature projects

4. **Code Documentation**:
   - JSDoc/TSDoc on exported components, hooks, Server Actions and the
     server data layer (sample)
   - Complex Route Handlers documented (request/response shape) or an
     OpenAPI description for public APIs

5. **Contributing Documentation**:
   - `CONTRIBUTING.md`, `CHANGELOG.md`
   - Git conventions documented (conventional commits, branch naming)

6. **Architecture Documentation**:
   - `docs/` directory, ADRs
   - Routing map / route groups explained, caching strategy explained
     (which data is cached, for how long, and what revalidates it),
     rendering strategy per area (static, dynamic, partially prerendered)
   - Monorepo: what each app/package is for

7. **Agent-facing documentation** (presence only — scored in the AI
   Harness section, recorded here for completeness):
   - `AGENTS.md` / `CLAUDE.md` at the root, including whether it carries
     the Next.js managed block (`<!-- BEGIN:nextjs-agent-rules -->`,
     written by `next dev` on Next.js 16.3+) that points agents at the
     version-matched docs in `node_modules/next/dist/docs/`
   - `.next-docs/` from `npx @next/codemod@canary agents-md` (Next.js
     16.1 and earlier)
   - Do not score these here; reference: https://nextjs.org/docs/app/guides/ai-agents

OUTPUT FORMAT:

Provide structured analysis:
- README present: [Yes/No] (create-next-app default: [Yes/No])
- README completeness: [Full/Partial/Minimal]
- .env.example present: [Yes/No] (covers referenced variables: [Yes/Partially/No])
- NEXT_PUBLIC_ variables documented: [Yes/No/N/A]
- Storybook configured: [Yes/No]
- Stories files count: [XX]
- JSDoc coverage: [High/Medium/Low/None]
- CONTRIBUTING.md: [Yes/No]
- Architecture docs: [Yes/No/Partial] (caching strategy documented: [Yes/No])
- Agent-facing docs: [AGENTS.md/CLAUDE.md/managed Next.js block/.next-docs/none]
- Missing critical documentation
- Risks identified
- Recommendations

SCORING GUIDANCE:

Strong (85-100):
- Project-specific README with all setup sections and the real package manager
- Complete .env.example with client/server exposure documented
- Architecture notes including caching and rendering strategy
- Key components, Server Actions and hooks documented

Fair (70-84):
- README present but missing some sections
- .env.example present but incomplete
- Some documentation present

Weak (0-69):
- No README, or the untouched create-next-app README
- No .env.example
- No component or architecture documentation
- No setup instructions
