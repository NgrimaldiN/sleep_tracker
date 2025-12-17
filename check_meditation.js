
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://wzvnlhctvtwaehkyeewe.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw';

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

async function checkMeditation() {
    console.log('Fetching logs...');

    const { data: logs, error } = await supabase
        .from('daily_logs')
        .select('*');

    if (error) {
        console.error(error);
        return;
    }

    let withCount = 0;
    let withoutCount = 0;
    let total = logs.length;

    logs.forEach(log => {
        const habits = log.data.habits || [];
        if (habits.includes('meditation')) {
            withCount++;
        } else {
            withoutCount++;
        }
    });

    console.log(`Total Logs: ${total}`);
    console.log(`With Meditation: ${withCount}`);
    console.log(`Without Meditation: ${withoutCount}`);

    if (withCount === 0 || withoutCount === 0) {
        console.log('ISSUE FOUND: One group has 0 entries, preventing analysis.');
    } else {
        console.log('Data looks correct for analysis (both > 0). User might need to refresh.');
    }
}

checkMeditation();
