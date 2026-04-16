import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;

if (!url || !anonKey) {
  throw new Error(
    'Missing SUPABASE_URL or SUPABASE_ANON_KEY. Example: node --env-file=assets/app.env tools/your-script.mjs',
  );
}

export const supabase = createClient(url, anonKey);
