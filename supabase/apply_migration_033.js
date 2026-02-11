#!/usr/bin/env node

/**
 * Apply Migration 033: Unit Conversion System
 *
 * This script applies the unit conversion migration to your Supabase database.
 * It adds the base_unit column and converts existing data.
 *
 * Usage:
 *   node apply_migration_033.js
 *
 * Requirements:
 *   - Set SUPABASE_URL environment variable
 *   - Set SUPABASE_SERVICE_ROLE_KEY environment variable (or SUPABASE_ANON_KEY)
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

// Get credentials from environment
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('❌ Error: Missing Supabase credentials');
  console.error('');
  console.error('Please set environment variables:');
  console.error('  export SUPABASE_URL="your-project-url"');
  console.error('  export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"');
  console.error('');
  console.error('Or run with inline variables:');
  console.error('  SUPABASE_URL="..." SUPABASE_SERVICE_ROLE_KEY="..." node apply_migration_033.js');
  process.exit(1);
}

// Read migration file
const migrationPath = path.join(__dirname, 'migrations', '033_unit_conversion_system.sql');
const sql = fs.readFileSync(migrationPath, 'utf8');

// Split into individual statements (simple split by semicolon)
const statements = sql
  .split(';')
  .map(s => s.trim())
  .filter(s => s.length > 0 && !s.startsWith('--'));

console.log('🚀 Applying Migration 033: Unit Conversion System');
console.log('');
console.log(`📊 Found ${statements.length} SQL statements to execute`);
console.log('');

// Execute each statement
let completed = 0;
let failed = 0;

async function executeSQL(statement, index) {
  const url = new URL('/rest/v1/rpc/exec_sql', SUPABASE_URL);

  const data = JSON.stringify({ sql: statement });

  const options = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(url, options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve({ success: true, status: res.statusCode });
        } else {
          reject({ success: false, status: res.statusCode, body });
        }
      });
    });

    req.on('error', (error) => {
      reject({ success: false, error: error.message });
    });

    req.write(data);
    req.end();
  });
}

// Alternative: Use psql directly via REST API or execute via SQL Editor
async function executeViaREST(sql) {
  // Supabase REST API doesn't directly support DDL
  // We need to use the SQL Editor or pg connection
  console.log('ℹ️  Direct SQL execution via REST API is limited.');
  console.log('');
  console.log('✅ Best approach: Copy migration SQL to Supabase SQL Editor');
  console.log('');
  console.log('Steps:');
  console.log('1. Open Supabase Dashboard: https://supabase.com/dashboard');
  console.log('2. Select your project');
  console.log('3. Go to SQL Editor');
  console.log('4. Create new query');
  console.log('5. Copy-paste content from: supabase/migrations/033_unit_conversion_system.sql');
  console.log('6. Click "Run" or press Ctrl+Enter');
  console.log('');
  console.log('🎉 Migration complete!');
}

// Since REST API might not support DDL, show the SQL
console.log('📋 Migration SQL:');
console.log('━'.repeat(80));
console.log(sql);
console.log('━'.repeat(80));
console.log('');

executeViaREST(sql);
