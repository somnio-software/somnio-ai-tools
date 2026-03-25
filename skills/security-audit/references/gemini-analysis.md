# Security Gemini Analysis

> Execute advanced AI-powered security analysis using the Gemini CLI Security extension. Framework-agnostic. Skips gracefully if Gemini CLI is unavailable.

---

Goal: Execute advanced security analysis using the Gemini CLI Security
extension if available. Skip gracefully if Gemini CLI or authentication
is unavailable.

PREREQUISITES CHECK:

1. Check Gemini CLI Installation:
   ```bash
   if ! command -v gemini &> /dev/null; then
     echo "SKIP: Gemini CLI not installed."
     echo "Gemini AI analysis is not available."
     echo "To install: npm install -g @google/gemini-cli"
     exit 0
   fi
   echo "Gemini CLI: INSTALLED"
   ```

2. Check Authentication (API key OR subscription):
   ```bash
   if [ -z "$GEMINI_API_KEY" ] && [ -z "$GOOGLE_API_KEY" ]; then
     # No API key, check subscription
     AUTH_STATUS=$(gemini auth status 2>&1)
     if ! echo "$AUTH_STATUS" | grep -qi "authenticated\|logged in\|active"; then
       echo "SKIP: No Gemini API key or subscription found."
       echo "Gemini AI analysis is not available."
       echo "To enable: set GEMINI_API_KEY or run 'gemini auth login'"
       exit 0
     fi
     echo "Authentication: Subscription"
   else
     echo "Authentication: API key"
   fi
   ```

3. Check Security Extension:
   ```bash
   if ! gemini extensions list 2>/dev/null | grep -q "security"; then
     echo "Security extension not found. Installing..."
     gemini extensions install \
       https://github.com/gemini-cli-extensions/security > /dev/null 2>&1
     if [ $? -ne 0 ]; then
       echo "SKIP: Failed to install security extension."
       echo "Continuing without Gemini AI analysis."
       exit 0
     fi
     echo "Security extension: INSTALLED"
   else
     echo "Security extension: AVAILABLE"
   fi
   ```

4. Execute Security Analysis:
   ```bash
   echo "Running Gemini Security Analysis..."
   mkdir -p reports/.artifacts
   gemini prompt "/security:analyze" > reports/.artifacts/step_09_security_gemini_analysis.md 2>&1

   if [ $? -eq 0 ]; then
     echo "Gemini Security Analysis completed successfully."
     echo "Report saved to reports/.artifacts/step_09_security_gemini_analysis.md"
     head -20 reports/.artifacts/step_09_security_gemini_analysis.md 2>/dev/null || \
       echo "Report file exists"
   else
     echo "Gemini Security Analysis failed or required interaction."
     head -20 reports/.artifacts/step_09_security_gemini_analysis.md 2>/dev/null || \
       echo "Report file exists"
   fi

   # Clean up side-effect files created by Gemini CLI security extension
   rm -f security_analysis_prompt.txt gemini_security_findings.txt gemini_security_report.txt
   ```

Output format:
- Gemini CLI status (installed/not installed)
- Authentication method (API key/subscription/none)
- Security Extension status (installed/not installed)
- Analysis execution status (completed/failed/skipped)
- Summary of findings from the security analysis (if completed)
- Location of the detailed report (reports/.artifacts/step_09_security_gemini_analysis.md)
