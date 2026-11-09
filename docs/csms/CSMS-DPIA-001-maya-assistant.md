# CSMS-DPIA-001 — Maya Assistant (AI)

## Processing

Maya Assistant is an optional Edge Function. It sends the user’s prompt plus a **counts-only** live snapshot (`students=N`, not names) to a generative model (Gemini) when `MAYA_AI_API_KEY` is set.

## Necessity

Help staff with in-app workflows. It is not required for SIS, marks, or attendance.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Child’s name in the prompt | System instruction: do not invent PII; refuse health/safeguarding/passwords; do not ask for children’s IDs |
| Whole registry in context | Live context is counts only |
| School without AI | If the key is missing, the function returns 412; the rest of the ERP works |

## Decision

Maya may stay enabled. Schools that forbid external AI leave the key unset. No medical or safeguarding module is wired as automatic context.
