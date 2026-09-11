import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://vbgisehknnhnlatfdyri.supabase.co'; // ganti jika perlu
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY_HERE'; // ganti dengan anon key

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const run = async () => {
  const { data, error } = await supabase.auth.signInWithPassword({
    email: 'faizollama11@gmail.com',
    password: '123456',
  });
  if (error) {
    console.error('Error login:', error);
    return;
  }
  console.log('Access token:', data.session?.access_token);
};

run();
