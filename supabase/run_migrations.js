const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const migrations = [
  '001_core_tables.sql',
  '002_ai_tables.sql',
  '003_views_functions_rls.sql',
  '004_seed_data.sql',
];

async function run() {
  // Try multiple connection methods
  const configs = [
    {
      name: 'IPv6 direct',
      config: {
        host: '2406:da12:b78:de0d:32bc:33b9:839e:b91f',
        port: 5432,
        database: 'postgres',
        user: 'postgres',
        password: 'diandra221022!',
        ssl: { rejectUnauthorized: false },
        connectionTimeoutMillis: 15000
      }
    },
    {
      name: 'Hostname port 5432',
      config: {
        host: 'db.eavsygnrluburvrobvoj.supabase.co',
        port: 5432,
        database: 'postgres',
        user: 'postgres',
        password: 'diandra221022!',
        ssl: { rejectUnauthorized: false },
        connectionTimeoutMillis: 15000
      }
    },
    {
      name: 'Hostname port 6543 (pooler)',
      config: {
        host: 'db.eavsygnrluburvrobvoj.supabase.co',
        port: 6543,
        database: 'postgres',
        user: 'postgres',
        password: 'diandra221022!',
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
