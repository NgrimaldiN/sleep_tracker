
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const supabaseUrl = 'https://wzvnlhctvtwaehkyeewe.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw';

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

const LOG_FILE = 'fake_meditation_dates.json';

async function revertData() {
    console.log('--- Starting Fake Data Cleanup ---');

    if (!fs.existsSync(LOG_FILE)) {
        console.error(`Log file ${LOG_FILE} not found. Cannot revert automatically.`);
        return;
    }

    const datesToRevert = JSON.parse(fs.readFileSync(LOG_FILE, 'utf8'));
    console.log(`Found ${datesToRevert.length} dates to clean up.`);

    for (const date of datesToRevert) {
        // Fetch current log
        const { data: log, error: fetchError } = await supabase
            .from('daily_logs')
            .select('*')
            .eq('date', date)
            .single();

        if (fetchError || !log) {
            console.error(`Error fetching log for ${date}:`, fetchError);
            continue;
        }

        const currentData = log.data;
        const currentHabits = currentData.habits || [];

        // Remove meditation
        if (currentHabits.includes('meditation')) {
            const updatedHabits = currentHabits.filter(h => h !== 'meditation');
            const updatedData = { ...currentData, habits: updatedHabits };

            const { error: updateError } = await supabase
                .from('daily_logs')
                .update({ data: updatedData })
                .eq('date', date);

            if (updateError) {
                console.error(`Failed to revert ${date}:`, updateError);
            } else {
                console.log(`Removed meditation from ${date}`);
            }
        } else {
            console.log(`No meditation found on ${date}, skipping.`);
        }
    }

    console.log('\nCleanup Complete. You can delete the log file now.');
}

revertData();
