#!/data/data/com.termux/files/usr/bin/bash

set +e

PROJECT_REF="ysjyyhgzhpdtdtrwqqwk"
PROJECT_URL="https://${PROJECT_REF}.supabase.co"

OUTPUT="$HOME/storage/downloads/INTLY_SUPABASE_COMPLETE_EXPORT.txt"
TEMP="$HOME/intly_export_temp"

mkdir -p "$TEMP"
rm -f "$OUTPUT"

section() {
    echo "" >> "$OUTPUT"
    echo "============================================================" >> "$OUTPUT"
    echo "$1" >> "$OUTPUT"
    echo "============================================================" >> "$OUTPUT"
}

command_section() {
    TITLE="$1"
    shift

    section "$TITLE"

    "$@" >> "$OUTPUT" 2>&1

    if [ $? -ne 0 ]; then
        echo "[Export command failed. See output above.]" >> "$OUTPUT"
    fi
}

echo "INTLY SUPABASE COMPLETE PROJECT EXPORT" > "$OUTPUT"
echo "Export date: $(date)" >> "$OUTPUT"
echo "Project ref: $PROJECT_REF" >> "$OUTPUT"
echo "Project URL: $PROJECT_URL" >> "$OUTPUT"

section "1. SUPABASE CLI VERSION"
supabase --version >> "$OUTPUT" 2>&1

section "2. PROJECT LINK STATUS"
supabase projects list >> "$OUTPUT" 2>&1

section "3. SUPABASE SECRET NAMES"
echo "Secret values are intentionally NOT exported." >> "$OUTPUT"
supabase secrets list --project-ref "$PROJECT_REF" >> "$OUTPUT" 2>&1

section "4. REMOTE EDGE FUNCTIONS"
supabase functions list --project-ref "$PROJECT_REF" >> "$OUTPUT" 2>&1

section "5. DATABASE SCHEMA DUMP"
echo "Exporting public schema: tables, columns, constraints, indexes, functions, triggers and policies." >> "$OUTPUT"

supabase db dump \
    --project-ref "$PROJECT_REF" \
    --schema public \
    -f "$TEMP/public_schema.sql" >> "$OUTPUT" 2>&1

if [ -f "$TEMP/public_schema.sql" ]; then
    cat "$TEMP/public_schema.sql" >> "$OUTPUT"
else
    echo "WARNING: Database schema dump was not created." >> "$OUTPUT"
fi

section "6. ALL DATABASE MIGRATIONS"

if [ -d supabase/migrations ]; then
    find supabase/migrations -maxdepth 1 -type f -name '*.sql' | sort | while read -r FILE; do
        echo "" >> "$OUTPUT"
        echo "----- $FILE -----" >> "$OUTPUT"
        cat "$FILE" >> "$OUTPUT"
    done
else
    echo "No migrations directory found." >> "$OUTPUT"
fi

section "7. ALL LOCAL EDGE FUNCTION SOURCE CODE"

if [ -d supabase/functions ]; then
    find supabase/functions -type f | sort | while read -r FILE; do
        case "$FILE" in
            *.env|*.env.*|*/.env|*/.env.*|*.pem|*.key)
                echo "SKIPPED PRIVATE FILE: $FILE" >> "$OUTPUT"
                continue
                ;;
        esac

        echo "" >> "$OUTPUT"
        echo "----- $FILE -----" >> "$OUTPUT"
        cat "$FILE" >> "$OUTPUT"
    done
else
    echo "No Edge Functions directory found." >> "$OUTPUT"
fi

section "8. SUPABASE CONFIGURATION"

if [ -f supabase/config.toml ]; then
    cat supabase/config.toml >> "$OUTPUT"
else
    echo "supabase/config.toml not found." >> "$OUTPUT"
fi

section "9. PROJECT FILE STRUCTURE"

find . -maxdepth 3 -type f \
    ! -path './.git/*' \
    ! -path './.dart_tool/*' \
    ! -path './build/*' \
    ! -name '.env' \
    ! -name '.env.*' \
    ! -name '*.jks' \
    ! -name '*.keystore' \
    ! -name '*.pem' \
    ! -name '*.key' \
    | sort >> "$OUTPUT"

section "10. EXPORT COMPLETED"
echo "Project: $PROJECT_REF" >> "$OUTPUT"
echo "Output: $OUTPUT" >> "$OUTPUT"
echo "Secret values were not exported." >> "$OUTPUT"

rm -rf "$TEMP"

echo ""
echo "=========================================="
echo "INTLY EXPORT FINISHED"
echo "=========================================="
echo "File: $OUTPUT"
echo ""

if [ -f "$OUTPUT" ]; then
    ls -lh "$OUTPUT"
    echo ""
    echo "Download folder:"
    ls -lh ~/storage/downloads/INTLY_SUPABASE_COMPLETE_EXPORT.txt
fi
