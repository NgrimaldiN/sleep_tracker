
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://wzvnlhctvtwaehkyeewe.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw';

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

async function verify() {
    const { data: logs } = await supabase.from('daily_logs').select('*');

    let meditationCount = 0;
    logs.forEach(l => {
        if ((l.data.habits || []).includes('meditation')) meditationCount++;
    });

    console.log(`Total Days with Meditation: ${meditationCount}`);
    if (meditationCount === 7) {
        console.log('SUCCESS: Exactly 7 days have meditation.');
    } else {
        console.log(`WARNING: Expected 7, found ${meditationCount}.`);
    }
}

verify();
