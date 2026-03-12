
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://wzvnlhctvtwaehkyeewe.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw';

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false }
});

async function inspectData() {
    console.log('Fetching data...');

    // 1. Fetch Habits
    const { data: habits, error: habitsError } = await supabase
        .from('habits')
        .select('*');

    if (habitsError) {
        console.error('Error fetching habits:', habitsError);
        return;
    }

    // 2. Fetch Logs
    const { data: logs, error: logsError } = await supabase
        .from('daily_logs')
        .select('*');

    if (logsError) {
        console.error('Error fetching logs:', logsError);
        return;
    }
    console.log(`\nFetched ${logs.length} logs.`);

    // 3. Analyze specific habit if identifiable, or all numeric ones
    const numericHabits = habits.filter(h => h.type === 'number'); // Only number types

    console.log('\n--- Numeric Habit Analysis ---');
    numericHabits.forEach(habit => {
        console.log(`\nAnalyzing Habit: ${habit.label} (${habit.id})`);

        const values = [];
        const zeroOrMissing = [];

        logs.forEach(log => {
            const val = log.data.habitValues && log.data.habitValues[habit.id];
            const hasSleepScore = log.data.sleepScore !== null && log.data.sleepScore !== undefined;

            // In DB, value is stored. In logic, if val > 0 it is "Active".
            if (val !== undefined && val !== null && val > 0) {
                if (hasSleepScore) values.push({ date: log.date, value: val });
            } else {
                if (hasSleepScore) zeroOrMissing.push({ date: log.date, score: log.data.sleepScore });
            }
        });

        console.log(`Days with value > 0 AND Sleep Score: ${values.length}`);
        console.log(`Days without value AND Sleep Score: ${zeroOrMissing.length}`);

        if (zeroOrMissing.length === 0) {
            console.log('Reason for no result: No days WITHOUT this habit have a valid Sleep Score recorded.');
        } else {
            console.log('Sample days without habit (with score):', zeroOrMissing.slice(0, 5));
        }

        if (values.length > 0) {
            const nums = values.map(v => parseFloat(v.value)).filter(n => !isNaN(n));
            if (nums.length > 0) {
                const min = Math.min(...nums);
                const max = Math.max(...nums);
                const avg = nums.reduce((a, b) => a + b, 0) / nums.length;
                console.log(`Stats: Min=${min}, Max=${max}, Avg=${avg.toFixed(2)}`);
                console.log('Sample output values:', values.slice(0, 5).map(v => `${v.date}: ${v.value}`).join(', '));
            }
        }
    });
}

inspectData();
