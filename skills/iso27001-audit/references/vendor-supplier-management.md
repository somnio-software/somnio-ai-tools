# Category I - Vendor / Third-Party (Supplier) Management Evidence (A.5.19-A.5.23)

> Gather in-repo evidence for supplier security, cloud-service security, and supplier agreements. Framework-agnostic, read-only. Supplier-security POLICY is ORGANIZATIONAL; the actual dependency/cloud footprint is PLATFORM-AUDITABLE.

---

Goal: Determine whether supplier and cloud-service risks are managed. Record
Status + Owner/lane per control.

PROJECT DETECTION (execute first):
- Read `reports/.artifacts/step_01_iso27001_project_detection.md` for
  package managers and IaC surfaces.

CONTROL EVIDENCE:

A.5.19 Information security in supplier relationships / A.5.20 Addressing
security within supplier agreements (ORGANIZATIONAL) - supplier register, DPAs,
security addenda:
```bash
find . -maxdepth 5 \( -iname "*supplier*" -o -iname "*vendor*" -o -iname "*third-?party*" -o -iname "*dpa*" -o -iname "*data-processing*agreement*" -o -iname "*subprocessor*" -o -iname "*sub-processor*" \) -not -path "*/node_modules/*" 2>/dev/null | head -20 || echo "No supplier-management / DPA artifacts found"
```

A.5.21 Managing information security in the ICT supply chain
(PLATFORM-AUDITABLE) - SBOM, pinned dependencies, provenance:
```bash
find . \( -iname "sbom*" -o -iname "*.spdx*" -o -iname "*cyclonedx*" -o -name "*.lock" -o -name "package-lock.json" -o -name "go.sum" \) -not -path "*/node_modules/*" 2>/dev/null | head -20 || echo "No SBOM / pinned-dependency evidence found"
# Enumerate the actual third-party footprint (top-level deps as suppliers):
for mf in package.json requirements.txt pyproject.toml go.mod Cargo.toml pubspec.yaml Gemfile pom.xml build.gradle; do
  find . -name "$mf" -not -path "*/node_modules/*" 2>/dev/null | head -5
done
```

A.5.22 Monitoring, review and change management of supplier services
(PLATFORM-AUDITABLE where automated) - dependency update automation, renovate/
dependabot (cross-reference Category G):
```bash
find . \( -path "*/.github/dependabot.yml" -o -name "renovate.json" \) -not -path "*/node_modules/*" 2>/dev/null | head -10 || echo "No supplier/dependency-monitoring automation found"
```

A.5.23 Information security for use of cloud services (PLATFORM-AUDITABLE) -
cloud provider config, managed-service usage, cloud-security posture:
```bash
grep -rniE "aws|amazon|gcp|google cloud|azure|cloudflare|vercel|netlify|heroku|digitalocean|s3|rds|dynamodb|lambda|cloud ?run|aks|eks|gke" . --include=*.tf --include=*.yaml --include=*.yml --include=*.tfvars 2>/dev/null | grep -v node_modules | head -25 || echo "No cloud-service usage evidence found"
find . -maxdepth 5 -iname "*cloud*security*polic*" -o -iname "*cloud*use*polic*" 2>/dev/null | grep -v node_modules | head -5 || echo "No cloud-service-use policy artifact found"
```

READ-ONLY + SECRET SAFETY: read only; redact any secret VALUE (cloud keys,
tokens) as `[REDACTED]`; never copy the value.

ARTIFACT SAVE (mandatory):
Save output to: reports/.artifacts/step_10_iso27001_vendor_supplier_management.md
Run before finishing: mkdir -p reports/.artifacts

Output format:
- Category I control table: Annex A ref | control name | Status | Owner/lane |
  evidence (path) or "No evidence found" | gap + satisfying artifact
- Third-party footprint summary: manifests found, whether an SBOM exists,
  whether supplier/cloud policy artifacts exist
- Summary: count of Met / Partial / Gap / Organizational
