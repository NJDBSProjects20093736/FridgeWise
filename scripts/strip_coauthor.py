"""Remove Cursor co-author line from git commit message (stdin -> stdout)."""
import sys

for line in sys.stdin:
    if "Co-authored-by: Cursor" in line:
        continue
    sys.stdout.write(line)
