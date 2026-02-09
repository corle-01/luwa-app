const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

// Load from environment variables or .env file
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const migrations = [
  '001_core_tables.sql',
  '002_ai_tables.sql',
  '003_views_functions_rls.sql',
  '004_seed_data.sql',
];

async function run() {
  const host = process.env.DB_HOST;
  const password = process.env.DB_PASSWORD;

  if (!host || !password) {
    console.error('Missing DB_HOST or DB_PASSWORD environment variables.');
    console.error('Set them in .env file or export them before running.');
    return;
  }

  // Try multiple connection methods
  const configs = [
    {
      name: 'Hostname port 5432',
      config: {
        host,
        port: parseInt(process.env.DB_PORT || '5432'),
        database: process.env.DB_NAME || 'postgres',
        user: process.env.DB_USER || 'postgres',
        password,
        ssl: { rejectUnauthorized: false },
        connectionTimeoutMillis: 15000
      }
    },
    {
      name: 'Hostname port 6543 (pooler)',
      config: {
        host,
        port: 6543,
        database: process.env.DB_NAME || 'postgres',
        user: process.env.DB_USER || 'postgres',
        password,
        ssl: { rejectUnauthorized: false },
        connectionTimeoutMillis: 15000
      }
    }
  ];

  let connected = false;
  let client;

  for (const { name, config } of configs) {
    console.log(`Trying: ${name}...`);
    client = new Client(config);
    try {
      await client.connect();
      console.log(`  Connected via ${name}!\n`);
      connected = true;
      break;
    } catch (err) {
      console.log(`  Failed: ${err.message}`);
      try { await client.end(); } catch (_) {}
    }
  }

  if (!connected) {
    console.error('\nAll connection methods failed.');
    console.log('Please run the SQL files manually in Supabase SQL Editor.');
    return;
  }

  for (const file of migrations) {
    const filePath = path.join(__dirname, 'migrations', file);
    const sql = fs.readFileSync(filePath, 'utf8');
    console.log(`Running ${file}...`);
    try {
      await client.query(sql);
      console.log(`  ${file} - SUCCESS\n`);
    } catch (err) {
      console.error(`  ${file} - ERROR: ${err.message}\n`);
    }
  }

  const result = await client.query(`
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE'
    ORDER BY table_name;
  `);

  console.log('=== Tables Created ===');
  result.rows.forEach((row, i) => {
    console.log(`  ${i + 1}. ${row.table_name}`);
  });
  console.log(`\nTotal: ${result.rows.length} tables`);

  await client.end();
}

run();
