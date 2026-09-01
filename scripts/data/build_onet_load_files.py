#!/usr/bin/env python3
"""Build Salesforce load files from the O*NET database and Military Crosswalk (NMDH-22).

Sources, both public and free:
  https://www.onetcenter.org/dl_files/database/db_29_1_text.zip   (Occupation Data.txt)
  https://www.onetcenter.org/dl_files/2019/military_crosswalk.zip (milx*.csv)

Produces occupations.csv and codes.csv for bulk upsert:
  sf data upsert bulk --sobject NM_Occupation__c        --file occupations.csv --external-id ONET_Code__c
  sf data upsert bulk --sobject NM_Military_Code_V2__c  --file codes.csv       --external-id External_Key__c

Notes learned the hard way:
  - Bulk API rejects embedded newlines; values are flattened.
  - Newly deployed fields are invisible until FLS is granted, or the load
    fails with "Field name not found".
"""
import csv, sys

SVC = {'A': 'Army', 'M': 'Marine Corps', 'N': 'Navy',
       'C': 'Coast Guard', 'F': 'Air Force', 'H': 'Air Force'}
# F and H are ~99% the same AFSC set (two component codes); merged and deduped.

def build(occ_txt, crosswalk_csv, out_occ='occupations.csv', out_codes='codes.csv'):
    occ_fields = ['Name', 'ONET_Code__c', 'Description__c']
    occs = []
    with open(occ_txt, encoding='utf-8') as f:
        for r in csv.DictReader(f, delimiter='\t'):
            occs.append({'Name': r['Title'][:80],
                         'ONET_Code__c': r['O*NET-SOC Code'],
                         'Description__c': r['Description']})
    _write(out_occ, occ_fields, occs)

    code_fields = ['Name', 'External_Key__c', 'Branch__c',
                   'Code_Value__c', 'Role_Title__c', 'ONET_Codes__c']
    seen = {}
    with open(crosswalk_csv, encoding='latin-1') as f:
        for r in csv.DictReader(f):
            if r['STATUS'] != 'A' or not r.get('ONET1'):
                continue
            branch = SVC.get(r['SVC'])
            code = (r['MOC'] or '').strip().upper()
            if not branch or not code or code == '-':
                continue
            key = f'{branch.upper()}|{code}'
            if key in seen:
                continue
            onets = [r.get(f'ONET{i}') for i in (1, 2, 3, 4)]
            onets = [o.strip() for o in onets if o and o.strip() and o.strip() != '-']
            if not onets:
                continue
            seen[key] = {'Name': code[:80], 'External_Key__c': key, 'Branch__c': branch,
                         'Code_Value__c': code, 'Role_Title__c': (r['MOC_TITLE'] or '')[:255],
                         'ONET_Codes__c': ';'.join(onets)[:255]}
    _write(out_codes, code_fields, list(seen.values()))
    print(f'occupations: {len(occs)}  military codes: {len(seen)}')

def _write(path, fields, rows):
    flat = [{k: (r.get(k) or '').replace('\r', ' ').replace('\n', ' ').strip() for k in fields}
            for r in rows]
    with open(path, 'w', newline='\n', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=fields, lineterminator='\n')
        w.writeheader()
        w.writerows(flat)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        sys.exit('usage: build_onet_load_files.py "<Occupation Data.txt>" <milx*.csv>')
    build(sys.argv[1], sys.argv[2])
