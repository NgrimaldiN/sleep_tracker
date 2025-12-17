
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://wzvnlhctvtwaehkyeewe.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw';

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

async function fixData() {
    console.log('Fetching log for 2025-11-28...');

    const TARGET_DATE = '2025-11-28';
    const HABIT_ID = 'screen_time_(phone)';
    const NEW_VALUE = 2; // User requested rounding 144 mins (2.4h) to 2

    // 1. Fetch specific log
    const { data: logs, error: fetchError } = await supabase
        .from('daily_logs')
        .select('*')
        .eq('date', TARGET_DATE)
        .single();

    if (fetchError) {
        console.error('Error fetching log:', fetchError);
        return;
    }

    if (!logs) {
        console.error('No log found for this date.');
        return;
    }

    console.log('Current Data:', JSON.stringify(logs.data.habitValues, null, 2));

    const currentValue = logs.data.habitValues[HABIT_ID];
    console.log(`Current value for ${HABIT_ID}: ${currentValue}`);

    if (currentValue !== 144) {
        console.log('Value is not 144, verifying if it needs update...');
        // Proceeding anyway but logging warning
    }

    // 2. Modify Data
    const updatedData = { ...logs.data };
    updatedData.habitValues = {
        ...updatedData.habitValues,
        [HABIT_ID]: NEW_VALUE
    };

    // 3. Update Supabase
    const { error: updateError } = await supabase
        .from('daily_logs')
        .update({ data: updatedData })
        .eq('date', TARGET_DATE);

    if (updateError) {
        console.error('Error updating log:', updateError);
    } else {
        console.log(`Successfully updated ${HABIT_ID} to ${NEW_VALUE} for date ${TARGET_DATE}`);
    }
}

fixData();
