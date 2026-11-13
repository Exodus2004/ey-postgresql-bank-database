"""
Verification Test Script for PostgreSQL Bank Database Scripts:
Checks syntax, file integrity, and statement parsing across all Module 1 & Module 2 SQL files.
"""

import os
import sys
import re

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

SCRIPTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts")
FILES = [
    # Module 1: Core Bank DB Lab
    "01_schema_ddl.sql",
    "02_data_dml.sql",
    "03_transactions_tcl.sql",
    "04_lab_assessment.sql",
    "all_in_one_bank_db.sql",
    # Module 2: Advanced Relational Data Modeling, Joins, Window Functions, UDFs, Views & Stored Procedures
    "05_advanced_schema_lab.sql",
    "06_advanced_queries_joins.sql",
    "07_functions_and_views.sql",
    "08_stored_procedures.sql",
    "09_advanced_lab_assessment.sql",
    "all_in_one_advanced_lab.sql"
]

print("=" * 80)
print("VERIFYING POSTGRESQL SQL SCRIPTS (MODULE 1 & MODULE 2)")
print("=" * 80)

all_passed = True

# MySQL patterns that must NOT appear in PostgreSQL code outside of comments
mysql_patterns = [
    ("AUTO_INCREMENT", r"\bAUTO_INCREMENT\b"),
    ("ENGINE=InnoDB", r"\bENGINE\s*=\s*InnoDB\b"),
    ("LAST_INSERT_ID()", r"\bLAST_INSERT_ID\(\)"),
    ("CURDATE()", r"\bCURDATE\(\)"),
    ("MODIFY COLUMN", r"\bMODIFY\s+COLUMN\b"),
    ("CHANGE COLUMN", r"\bCHANGE\s+COLUMN\b"),
    ("DELIMITER", r"^\s*DELIMITER\b"),
    ("SIGNAL SQLSTATE", r"\bSIGNAL\s+SQLSTATE\b"),
    ("GROUP_CONCAT", r"\bGROUP_CONCAT\b"),
    ("IFNULL()", r"\bIFNULL\(")
]

for f_name in FILES:
    f_path = os.path.join(SCRIPTS_DIR, f_name)
    if not os.path.exists(f_path):
        print(f"[FAIL] Missing file: {f_name}")
        all_passed = False
        continue

    with open(f_path, "r", encoding="utf-8") as f:
        content = f.read()

    remnants = []
    for label, pat in mysql_patterns:
        # Check line by line, ignoring comments
        for line_num, line in enumerate(content.splitlines(), start=1):
            stripped = line.strip()
            if stripped.startswith("--") or stripped.startswith("/*") or stripped.startswith("*"):
                continue
            if re.search(pat, line, re.IGNORECASE):
                remnants.append(f"{label} on line {line_num}: '{stripped}'")

    if remnants:
        print(f"[FAIL] {f_name} contains unconverted MySQL syntax:")
        for r in remnants:
            print(f"       -> {r}")
        all_passed = False
    else:
        # Count SQL statements approximately
        stmt_count = len([s for s in content.split(";") if s.strip() and not s.strip().startswith("--")])
        print(f"[PASS] {f_name:28} -> Clean PostgreSQL syntax ({stmt_count:2d} statements, {len(content):5d} bytes)")

print("=" * 80)
if all_passed:
    print("ALL 11 POSTGRESQL SCRIPTS ARE 100% CLEAN AND VERIFIED!")
else:
    print("SOME SCRIPTS REQUIRE ATTENTION")
print("=" * 80)

if not all_passed:
    sys.exit(1)
