const https = require('https');

const SUPABASE_URL = 'https://oyuoqqqsfjfslgbchdfp.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95dW9xcXFzZmpmc2xnYmNoZGZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAyNzQ0MDIsImV4cCI6MjEwNTg1MDQwMn0.oSvZkwFxmsBZEj-xUh7I6zYxn4emFyXitBpm1OhvzII';

function request(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${SUPABASE_URL}${path}`);
    const options = {
      method,
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      }
    };

    const req = https.request(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve(data);
        }
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

// Calculate business date with 3 AM cutoff
function calculateBusinessDate(isoString) {
  const dt = new Date(isoString);
  // Add 5.5 hours for IST
  const istMillis = dt.getTime() + (5.5 * 60 * 60 * 1000);
  // Subtract 3 hours for 3 AM cutoff
  const bizMillis = istMillis - (3 * 60 * 60 * 1000);
  const bizDate = new Date(bizMillis);
  return bizDate.toISOString().slice(0, 10);
}

async function run() {
  console.log('Fetching all bills from Supabase...');
  const bills = await request('GET', '/rest/v1/bills?select=id,bill_number,created_at,business_date&order=created_at.asc');
  if (!Array.isArray(bills)) {
    console.error('Failed to fetch bills:', bills);
    return;
  }
  console.log(`Found ${bills.length} bills.`);

  // Group by business_date
  const byDate = {};
  for (const bill of bills) {
    const bizDate = bill.business_date || calculateBusinessDate(bill.created_at);
    if (!byDate[bizDate]) {
      byDate[bizDate] = [];
    }
    byDate[bizDate].push(bill);
  }

  // Update each bill to 001, 002, 003...
  for (const [bizDate, dayBills] of Object.entries(byDate)) {
    console.log(`Processing date ${bizDate} (${dayBills.length} bills)...`);
    // Sort ascending by created_at
    dayBills.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));

    for (let i = 0; i < dayBills.length; i++) {
      const b = dayBills[i];
      const newNum = String(i + 1).padStart(3, '0');
      if (b.bill_number !== newNum || !b.business_date) {
        console.log(`  Updating ${b.id} (${b.bill_number}) -> ${newNum}`);
        await request('PATCH', `/rest/v1/bills?id=eq.${b.id}`, {
          bill_number: newNum,
          business_date: bizDate
        });
      }
    }
  }

  console.log('Done updating all bills!');
}

run().catch(console.error);
