# Disentangle Remote Migration into Separate Files

Use this when you need to break down a single migration file into multiple migrations with separate concerns, especially when the migration has already been applied remotely.

## Prerequisites
- You have a migration file that combines multiple concerns (extensions, schemas, table changes, indexes, functions, etc.)
- The migration has already been applied to your remote database

## Steps

### 1. Create separate migration files
```
npx supabase migration new migration_name_1
sleep 1 # wait 1 second to prevent timestamp collisions
npx supabase migration new migration_name_2
# ... repeat for each concern
```

### 2. Populate each migration file
Extract the SQL from your original migration and add it to each new migration file. Each file should have a single, clear concern:
- Extensions setup
- Schema creation
- Table alterations
- Index creation
- Function creation
- Extension removal

### 3. Check for timestamp collisions
Supabase CLI may create multiple files with the same timestamp. Verify:
```
ls -la supabase/migrations/[timestamp]*.sql
```

If you see multiple files with the same timestamp, you need to fix this before proceeding.

### 4. Mark each migration as applied

#### d. Mark each unique migration as applied
```
npx supabase migration repair [unique_timestamp] --status applied
```

### 5. Verify the migration status
```
npx supabase migration list | grep [timestamp_prefix]
```

You should see each migration listed exactly once with matching local and remote versions.

### 6. Clean up
Delete the original migration file:
```
rm supabase/migrations/[original_timestamp_original_name].sql
```

## Common Pitfalls

- **Timestamp collisions**: Always check if multiple migrations have the same timestamp before marking them as applied
- **Order matters**: Migrations are applied in timestamp order - ensure dependencies are respected