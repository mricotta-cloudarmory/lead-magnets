#!/usr/bin/env bash

# Converts JSON to CSV using Python
json_to_csv() {
  python - "$1" <<EOF
import json
import sys
import csv

with open(sys.argv[1], 'r') as f:
    data = json.load(f)

writer = csv.writer(sys.stdout, lineterminator='\n')
writer.writerow(["Rule ID", "Policy Requirement", "Evidence Types", "Does This Rule Apply To Us?"])

for key, value in data.items():
    rule = value.get("rule", "")
    typ = value.get("type", "")
    evidence = "" if typ == "Category" else ";".join(value.get("evidence", []))
    required = "Category" if typ == "Category" else "Yes" if value.get("required") else "No"
    writer.writerow([key, rule, evidence, required])
EOF
}

# Converts CSV to JSON using Python
csv_to_json() {
  python - "$1" <<EOF
import csv
import json
import sys

result = {}
with open(sys.argv[1], 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        key = row["Rule ID"]
        rule = row["Policy Requirement"]
        evidence_field = row['Evidence Types']
        required_field = row['Does This Rule Apply To Us?']

        if (evidence_field == "Category") or (required_field == "Category"):
            result[key] = {
                "rule": rule,
                "type": "Category",
                "evidence": None,
                "required": False
            }
        else:
            evidence = evidence_field.split(';') if evidence_field else []
            required = True if required_field == "Yes" else False
            result[key] = {
                "rule": rule,
                "type": "Item",
                "evidence": evidence,
                "required": required
            }

json.dump(result, sys.stdout, indent=2)
EOF
}

# Main logic
if [[ "$1" == "--output" && "$2" =~ ^(csv|json)$ && "$3" == "--input" && -n "$4" ]]; then
  if [[ "$2" == "csv" ]]; then
    json_to_csv "$4"
  else
    csv_to_json "$4"
  fi
else
  echo "Usage: $0 --output [csv|json] --input <input_file_path>"
  exit 1
fi
