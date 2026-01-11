---
description: Fix migration history when remote and local timestamps don't match
---

# Realign Migration History

When migrations are committed to Supabase with timestamps that differ from git commits, use this process to repair the history.

## 1. Identify the mismatch

```bash
npx supabase migration list | tail <some-number>
```

Look for:
- Remote-only migrations (empty first column, timestamp in second column)
- Local-only migrations (timestamp in first column, empty second column)
- Pairs with slightly different timestamps (e.g., `20260109143114` remote vs `20260109143115` local)

## 2. Repair mismatched migrations

For each migration pair:

### Remote-only migrations (exist in Supabase but not in git):
Mark as reverted to remove from remote history:
```bash
npx supabase migration repair --status reverted <timestamp>
```
Use the remote timestamp (from the second column).

### Local-only migrations (exist in git but not in Supabase):
Mark as applied to align remote with local:
```bash
npx supabase migration repair --status applied <timestamp>
```
Use the local timestamp (from the first column).

## 3. Verify alignment

After repairs, verify both sides match:
```bash
npx supabase migration list | tail -15
```

All migrations should have timestamps in both columns (local and remote should match).
