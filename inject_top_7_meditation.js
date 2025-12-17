
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const supabaseUrl = 'https://wzvnlhctvtwaehkyeewe.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw';

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

const LOG_FILE = 'top7_meditation_log.json';

async function injectTop7() {
    console.log('--- Injecting Meditation for Top 7 Days ---');

    // 1. Fetch all logs
    const { data: logs, error } = await supabase
        .from('daily_logs')
        .select('*');

    if (error) {
        console.error(error);
        return;
    }

    // 2. Sort by sleep score (descending)
    // Filter out null scores just in case
    const validLogs = logs.filter(l => l.data.sleepScore !== null && l.data.sleepScore !== undefined);

    validLogs.sort((a, b) => b.data.sleepScore - a.data.sleepScore);

    console.log(`Total Valid Logs: ${validLogs.length}`);

    // 3. Identify Top 7 and Rest
    const top7 = validLogs.slice(0, 7);
    const rest = validLogs.slice(7);

    console.log('Top 7 Scores:', top7.map(l => l.data.sleepScore).join(', '));
    console.log('Rest Scores (sample):', rest.slice(0, 5).map(l => l.data.sleepScore).join(', '));

    const modifications = [];

    // 4. Update Top 7 -> Add Meditation
    for (const log of top7) {
        const currentHabits = log.data.habits || [];
        if (!currentHabits.includes('meditation')) {
            const updatedHabits = [...currentHabits, 'meditation'];
            await updateLog(log.date, log.data, updatedHabits);
            modifications.push({ date: log.date, action: 'added' });
        }
    }

    // 5. Update Rest -> Remove Meditation (to ensure clean control group)
    for (const log of rest) {
        const currentHabits = log.data.habits || [];
        if (currentHabits.includes('meditation')) {
            const updatedHabits = currentHabits.filter(h => h !== 'meditation');
            await updateLog(log.date, log.data, updatedHabits);
            modifications.push({ date: log.date, action: 'removed' });
        }
    }

    async function updateLog(date, data, newHabits) {
        const updatedData = { ...data, habits: newHabits };
        const { error: updateError } = await supabase
            .from('daily_logs')
            .update({ data: updatedData })
            .eq('date', date);

        if (updateError) console.error(`Failed update for ${date}:`, updateError);
        else console.log(`Updated ${date}: Habits = [${newHabits}]`);
    }

    // Save log for revert (just list of dates involved)
    fs.writeFileSync(LOG_FILE, JSON.stringify(modifications, null, 2));
    console.log(`\nOperation Complete. Modified ${modifications.length} entries.`);
}

injectTop7();
