
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://wzvnlhctvtwaehkyeewe.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw';

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

async function checkScores() {
    const { data: logs, error } = await supabase
        .from('daily_logs')
        .select('*');

    if (error) {
        console.error(error);
        return;
    }

    const withoutMeditation = logs.filter(l => !(l.data.habits || []).includes('meditation'));

    console.log(`Days WITHOUT Meditation: ${withoutMeditation.length}`);

    const validWithout = withoutMeditation.filter(l => l.data.sleepScore !== null && l.data.sleepScore !== undefined);

    console.log(`Days WITHOUT Meditation AND WITH Sleep Score: ${validWithout.length}`);

    if (validWithout.length === 0) {
        console.log('PROBLEM CONFIRMED: No control group (days without habit but WITH score).');
        console.log('To fix: We need some days WITHOUT meditation that have a sleep score (ideally low, to show improvement).');

        // Suggestion: Find days with low scores and ensure they DON'T have meditation.
        // Or if they don't exist, create them.
    } else {
        console.log('Control group exists:', validWithout.map(l => ({ date: l.date, score: l.data.sleepScore })));
    }
}

checkScores();
