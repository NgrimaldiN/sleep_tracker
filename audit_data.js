
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://wzvnlhctvtwaehkyeewe.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw';

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

async function auditData() {
    console.log('Fetching all logs to audit...');

    const { data: logs, error } = await supabase
        .from('daily_logs')
        .select('*')
        .order('date', { ascending: true });

    if (error) {
        console.error(error);
        return;
    }

    console.log(`Total Logs: ${logs.length}`);

    let goodDays = 0;
    let badDays = 0;
    let modifiedDays = 0;

    console.log('\n--- Sample Data ---');
    logs.forEach(log => {
        const s = log.data.sleepScore;
        const h = log.data.habits || [];
        const isMeditation = h.includes('meditation');

        let status = 'Neutral';
        if (s > 80) {
            goodDays++;
            status = 'Good';
        }
        if (s < 70 && s !== null) {
            badDays++;
            status = 'Bad (Potentially Injected)';
        }

        // Print usage
        console.log(`${log.date}: Score=${s}, Meditation=${isMeditation}, Status=${status}`);
    });

    console.log(`\nSummary:`);
    console.log(`Good Days (>80): ${goodDays}`);
    console.log(`Bad Days (<70): ${badDays}`);
    console.log(`(We injected approx 6 bad days and 12 meditation days)`);
}

auditData();
