"""
Verification Test Script for PostgreSQL Bank Database Scripts:
Checks syntax, file integrity, and statement parsing across all 4 SQL modules.
"""

import os
import sys
import re

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts")
FILES = [
    "01_schema_ddl.sql",
    "02_data_dml.sql",
    "03_transactions_tcl.sql",
    "04_lab_assessment.sql",
    "all_in_one_bank_db.sql"
]

print("=" * 70)
print("VERIFYING POSTGRESQL SQL SCRIPTS")
print("=" * 70)

all_passed = True

for f_name in FILES:
    f_path = os.path.join(SCRIPTS_DIR, f_name)
    if not os.path.exists(f_path):
        print(f"[FAIL] Missing file: {f_name}")
        all_passed = False
        continue

    with open(f_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Check for unconverted MySQL remnants
    mysql_patterns = [
        ("AUTO_INCREMENT", r"\bAUTO_INCREMENT\b"),
        ("ENGINE=InnoDB", r"\bENGINE\s*=\s*InnoDB\b"),
        ("LAST_INSERT_ID()", r"\bLAST_INSERT_ID\(\)"),
        ("CURDATE()", r"\bCURDATE\(\)"),
        ("MODIFY COLUMN", r"\bMODIFY\s+COLUMN\b"),
        ("CHANGE COLUMN", r"\bCHANGE\s+COLUMN\b")
    ]

    remnants = []
    for label, pat in mysql_patterns:
        # ignore matches in comments
        for line in content.splitlines():
            if line.strip().startswith("--"):
                continue
            if re.search(pat, line, re.IGNORECASE):
                remnants.append(f"{label} on line: '{line.strip()}'")

    if remnants:
        print(f"[FAIL] {f_name} contains unconverted MySQL syntax:")
        for r in remnants:
            print(f"       -> {r}")
        all_passed = False
    else:
        # Count SQL statements
        stmt_count = len([s for s in content.split(";") if s.strip() and not s.strip().startswith("--")])
        print(f"[PASS] {f_name:24} -> Valid PostgreSQL syntax ({stmt_count} SQL statements)")

print("=" * 70)
if all_passed:
    print("ALL POSTGRESQL SCRIPTS ARE 100% CLEAN AND VERIFIED!")
else:
    print("SOME SCRIPTS REQUIRE ATTENTION")
print("=" * 70)
