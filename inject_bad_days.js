
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const supabaseUrl = 'https://wzvnlhctvtwaehkyeewe.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw';

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

const LOG_FILE = 'fake_bad_days_dates.json';

async function injectBadDays() {
    console.log('--- Injecting Fake Bad Days (Control Group) ---');

    // 1. Fetch logs
    const { data: logs, error } = await supabase
        .from('daily_logs')
        .select('*');

    if (error) {
        console.error(error);
        return;
    }

    // 2. Find days WITHOUT meditation AND WITHOUT sleep score
    const targetLogs = logs.filter(l =>
        !(l.data.habits || []).includes('meditation') &&
        (l.data.sleepScore === null || l.data.sleepScore === undefined)
    );

    console.log(`Found ${targetLogs.length} candidate days for control group.`);

    const modifiedDates = [];

    // 3. Update them with LOW scores
    for (const log of targetLogs) {
        // Random score between 50 and 65
        const fakeScore = 50 + Math.floor(Math.random() * 16);

        const updatedData = {
            ...log.data,
            sleepScore: fakeScore,
            // Add some dummy duration if missing, to look realistic? 
            // Only sleepScore is needed for the specific analysis check though.
        };

        const { error: updateError } = await supabase
            .from('daily_logs')
            .update({ data: updatedData })
            .eq('date', log.date);

        if (updateError) {
            console.error(`Failed to update ${log.date}:`, updateError);
        } else {
            console.log(`Injected bad score (${fakeScore}) on ${log.date}`);
            modifiedDates.push({ date: log.date, previousData: log.data });
            // Saving previous data is better for revert, but complex JSON.
            // For simple revert, we just nullify the score again? 
            // Assuming they didn't have a score before (which we filtered for).
        }
    }

    // Save simple list of dates for revert
    fs.writeFileSync(LOG_FILE, JSON.stringify(modifiedDates.map(d => d.date), null, 2));
    console.log(`\nModified ${modifiedDates.length} days.`);
    console.log(`Saved to ${LOG_FILE} for revert.`);
}

injectBadDays();
