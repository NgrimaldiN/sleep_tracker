
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const supabaseUrl = 'https://wzvnlhctvtwaehkyeewe.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw';

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

const LOG_FILE = 'fake_bad_days_dates.json';

async function revertBadDays() {
    console.log('--- Reverting Fake Bad Days ---');

    if (!fs.existsSync(LOG_FILE)) {
        console.error(`Log file ${LOG_FILE} not found.`);
        return;
    }

    const datesToRevert = JSON.parse(fs.readFileSync(LOG_FILE, 'utf8'));

    for (const date of datesToRevert) {
        const { data: log, error: fetchError } = await supabase
            .from('daily_logs')
            .select('*')
            .eq('date', date)
            .single();

        if (log) {
            const updatedData = { ...log.data, sleepScore: null }; // Reset to null as it was before

            const { error: updateError } = await supabase
                .from('daily_logs')
                .update({ data: updatedData })
                .eq('date', date);

            if (!updateError) {
                console.log(`Reset sleepScore for ${date}`);
            }
        }
    }
    console.log('Revert complete.');
}

revertBadDays();
