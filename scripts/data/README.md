# Data build inputs

## wages.json — NMDH-23
BLS OEWS national file, May 2024. Rebuild:

```
curl -A "NextMission/1.0 (you@example.com)" -o oes.zip \
  https://www.bls.gov/oes/special-requests/oesm24nat.zip
```

BLS returns **403 to a default User-Agent**. It must carry contact details.

Join is `ONET_Code__c` minus its suffix -> BLS `OCC_CODE`. Coverage is 95.3% of
our 1,016 occupations: 934 match a detailed SOC, 34 fall back to the BLS broad
group (flagged `Is_Broad_Group__c`, and the agent must disclose it), and 48 have
no published median at all.

Bulk upsert needs **LF line endings**; the CLI declares LF on macOS and rejects
a CRLF file with `LineEnding is invalid on user data`.

## cluster_role_onet_map.json — NMDH-23
Hand-mapped O*NET code for each cluster role title whose name is not a verbatim
O*NET occupation. Only 24 of 69 were; the other 45 are plain-English titles
("Police Officer" rather than "Police and Sheriff's Patrol Officers") chosen
because the formal name is not what a veteran searches for. The code makes them
verifiably grounded and is what lets pay resolve on the description path.

Fuzzy matching was tried and rejected: it mapped Payroll Specialist to Skincare
Specialists and Police Officer to Compliance Officers.

## military_only_adjacency.json — NMDH-33 follow-up
Civilian destinations for the 19 military-only 55-xx SOCs, which together cover
1,001 code mappings. Without these the agent has nothing to offer on that path,
so it asked the veteran to describe a job it had just named and then repeated
itself when pushed. Never presented as what the code maps to.
