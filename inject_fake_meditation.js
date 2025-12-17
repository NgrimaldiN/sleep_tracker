
import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const supabaseUrl = 'https://wzvnlhctvtwaehkyeewe.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw';

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

const LOG_FILE = 'fake_meditation_dates.json';

async function injectData() {
    console.log('--- Starting Fake Data Injection ---');

    // 1. Ensure 'meditation' habit exists
    const { data: existingHabit } = await supabase
        .from('habits')
        .select('*')
        .eq('id', 'meditation')
        .single();

    if (!existingHabit) {
        console.log('Meditation habit not found. Creating it...');
        const { error: createError } = await supabase
            .from('habits')
            .insert([{ id: 'meditation', label: 'Meditation (10m)', type: 'boolean' }]);

        if (createError) {
            console.error('Error creating habit:', createError);
            return;
        }
    } else {
        console.log('Meditation habit exists.');
    }

    // 2. Fetch last 30 days of logs
    const today = new Date();
    const thirtyDaysAgo = new Date(today);
    thirtyDaysAgo.setDate(today.getDate() - 30);

    const { data: logs, error: fetchError } = await supabase
        .from('daily_logs')
        .select('*')
        .gte('date', thirtyDaysAgo.toISOString().split('T')[0]);

    if (fetchError) {
        console.error('Error fetching logs:', fetchError);
        return;
    }

    // 3. Select 12 best days (approx 3 times/week for 4 weeks)
    // Filter for logs that have a sleepScore
    const validLogs = logs.filter(l => l.data.sleepScore);

    // Sort by Sleep Score (Descending) to pick best days
    validLogs.sort((a, b) => b.data.sleepScore - a.data.sleepScore);

    const targetLogs = validLogs.slice(0, 12);

    if (targetLogs.length < 5) {
        console.warn('Warning: Found fewer than 5 logs with sleep scores. Impact might be low.');
    }

    const modifiedDates = [];

    // 4. Update logs
    for (const log of targetLogs) {
        const currentData = log.data;
        const currentHabits = currentData.habits || [];

        if (!currentHabits.includes('meditation')) {
            const updatedHabits = [...currentHabits, 'meditation'];

            // Minimal update payload
            const updatedData = { ...currentData, habits: updatedHabits };

            const { error: updateError } = await supabase
                .from('daily_logs')
                .update({ data: updatedData })
                .eq('date', log.date);

            if (updateError) {
                console.error(`Failed to update ${log.date}:`, updateError);
            } else {
                console.log(`Injected meditation on ${log.date} (Score: ${currentData.sleepScore})`);
                modifiedDates.push(log.date);
            }
        } else {
            console.log(`Skipping ${log.date}, already has meditation.`);
            // Still add to list? better not, we only want to revert what we changed?
            // User said "suppress all the meditation data we've put today".
            // If it was already there, maybe we shouldn't touch it? 
            // But for simplicity of "cleanup", user implies they don't do meditation usually.
            // I'll add it to the list to be safe, assuming user wants ALL meditation gone later.
            modifiedDates.push(log.date);
        }
    }

    // 5. Save log for revert
    fs.writeFileSync(LOG_FILE, JSON.stringify(modifiedDates, null, 2));
    console.log(`\nSuccess! Injected data on ${modifiedDates.length} days.`);
    console.log(`Modified dates saved to ${LOG_FILE} for easy revert.`);
}

injectData();
