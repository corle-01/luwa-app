const fs = require('fs');
const path = require('path');

// Load from environment variables or .env file
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env file');
  process.exit(1);
}

// Get all migration files in order
const migrationsDir = path.join(__dirname, 'migrations');
const migrationFiles = fs.readdirSync(migrationsDir)
  .filter(f => f.endsWith('.sql'))
  .sort();

console.log(`📋 Found ${migrationFiles.length} migration files\n`);

async function runMigrations() {
  const { createClient } = require('@supabase/supabase-js');

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    }
  });

  let successCount = 0;
  let errorCount = 0;

  for (const file of migrationFiles) {
    const filePath = path.join(migrationsDir, file);
    const sql = fs.readFileSync(filePath, 'utf8');

    console.log(`🔄 Running ${file}...`);

    try {
      // Execute SQL via Supabase REST API
      const { data, error } = await supabase.rpc('exec_sql', { sql_query: sql }).catch(async () => {
        // Fallback: try direct query if RPC doesn't exist
        const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/exec_sql`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': SERVICE_ROLE_KEY,
            'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
          },
          body: JSON.stringify({ sql_query: sql })
        });

        if (!response.ok) {
          // If RPC doesn't exist, we need to run migrations manually
          throw new Error('Cannot execute SQL via API. Please use SQL Editor in Supabase Dashboard.');
        }

        return { data: await response.json(), error: null };
      });

      if (error) {
        console.log(`  ❌ ERROR: ${error.message || JSON.stringify(error)}\n`);
        errorCount++;
      } else {
        console.log(`  ✅ SUCCESS\n`);
        successCount++;
      }
    } catch (err) {
      console.log(`  ⚠️  ${err.message}\n`);
      errorCount++;
    }
  }

  console.log('\n' + '='.repeat(50));
  console.log(`✅ Successful: ${successCount}`);
  console.log(`❌ Errors: ${errorCount}`);
  console.log(`📊 Total: ${migrationFiles.length}`);
  console.log('='.repeat(50));

  if (errorCount > 0) {
    console.log('\n⚠️  Some migrations failed.');
    console.log('💡 Recommended: Run migrations manually via Supabase SQL Editor');
    console.log(`   URL: ${SUPABASE_URL.replace('https://', 'https://supabase.com/dashboard/project/')}/editor`);
  }
}

runMigrations().catch(err => {
  console.error('❌ Fatal error:', err.message);
  console.log('\n💡 Alternative: Run migrations manually via Supabase SQL Editor');
  console.log('   1. Go to Supabase Dashboard > SQL Editor');
  console.log('   2. Copy-paste each migration file from supabase/migrations/');
  console.log('   3. Run them in order (001, 002, 003, ...)');
  process.exit(1);
});
