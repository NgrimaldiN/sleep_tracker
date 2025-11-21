import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://wzvnlhctvtwaehkyeewe.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind6dm5saGN0dnR3YWVoa3llZXdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU1NTgsImV4cCI6MjA3OTMwMTU1OH0.jmCzqyjnmVpNjYNfndoWDqCWQ6aNix1rngUgVP8Z1yw';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testSupabase() {
    console.log('Testing Supabase Connection...');

    // 1. Try to fetch habits
    const { data: habits, error: fetchError } = await supabase
        .from('habits')
        .select('*')
        .limit(1);

    if (fetchError) {
        console.error('Error fetching habits:', fetchError);
    } else {
        console.log('Successfully fetched habits:', habits);
    }

    // 2. Try to insert a test habit
    const testHabit = {
        id: `debug_habit_${Date.now()}`,
        label: 'Debug Habit',
        type: 'boolean',
        user_id: null // Explicitly null as per schema
    };

    console.log('Attempting to insert test habit:', testHabit);

    const { data: insertData, error: insertError } = await supabase
        .from('habits')
        .insert([testHabit])
        .select();

    if (insertError) {
        console.error('Error inserting habit:', insertError);
    } else {
        console.log('Successfully inserted habit:', insertData);

        // Clean up
        console.log('Cleaning up test habit...');
        const { error: deleteError } = await supabase
            .from('habits')
            .delete()
            .eq('id', testHabit.id);

        if (deleteError) console.error('Error deleting test habit:', deleteError);
        else console.log('Cleanup successful.');
    }
}

testSupabase();
