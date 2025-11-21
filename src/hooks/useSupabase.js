import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';

export function useSupabase() {
    const [dailyLog, setDailyLog] = useState({});
    const [habits, setHabits] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    // Fetch initial data
    useEffect(() => {
        async function fetchData() {
            try {
                setLoading(true);

                // Fetch habits
                let { data: habitsData, error: habitsError } = await supabase
                    .from('habits')
                    .select('*')
                    .order('sort_order', { ascending: true })
                    .order('created_at', { ascending: true });

                if (habitsError) throw habitsError;

                // Seed default habits if empty
                if (!habitsData || habitsData.length === 0) {
                    const DEFAULT_HABITS = [
                        { id: 'caffeine', label: 'No caffeine after 2 PM' },
                        { id: 'screens', label: 'No screens 1h before bed' },
                        { id: 'read', label: 'Read a book' },
                        { id: 'magnesium', label: 'Took Magnesium' },
                        { id: 'meditation', label: 'Meditation (10m)' },
                        { id: 'hot_shower', label: 'Hot shower/bath' },
                    ];

                    const { error: seedError } = await supabase
                        .from('habits')
                        .insert(DEFAULT_HABITS);

                    if (seedError) {
                        console.error('Error seeding habits:', seedError);
                    } else {
                        habitsData = DEFAULT_HABITS;
                    }
                }

                // Fetch logs
                const { data: logsData, error: logsError } = await supabase
                    .from('daily_logs')
                    .select('*');

                if (logsError) throw logsError;

                // Transform logs array to object map { date: data }
                const logsMap = {};
                if (logsData) {
                    logsData.forEach(log => {
                        logsMap[log.date] = log.data;
                    });
                }

                setHabits(habitsData || []);
                setDailyLog(logsMap);
            } catch (err) {
                console.error('Error fetching data:', err);
                setError(err.message);
            } finally {
                setLoading(false);
            }
        }

        fetchData();
    }, []);

    // Sync Habits to Supabase
    const updateHabits = useCallback(async (newHabits) => {
        // Optimistic update
        setHabits(newHabits);

        try {
            console.log('Syncing habits to Supabase:', newHabits);
            const { data, error } = await supabase
                .from('habits')
                .upsert(newHabits, { onConflict: 'id' })
                .select();

            if (error) {
                console.error('Supabase upsert error:', error);
                throw error;
            }
            console.log('Supabase sync success:', data);
        } catch (err) {
            console.error('Error syncing habits:', err);
        }
    }, []);

    // Sync Daily Log to Supabase
    const updateDailyLog = useCallback(async (newLogOrUpdater) => {
        // Handle functional updates
        let newLog;
        if (typeof newLogOrUpdater === 'function') {
            setDailyLog(prev => {
                newLog = newLogOrUpdater(prev);
                return newLog;
            });
        } else {
            newLog = newLogOrUpdater;
            setDailyLog(newLog);
        }

        try {
            const updates = Object.entries(newLog).map(([date, data]) => ({
                date,
                data
            }));

            if (updates.length === 0) return;

            const { error } = await supabase
                .from('daily_logs')
                .upsert(updates, { onConflict: 'date' });

            if (error) throw error;
        } catch (err) {
            console.error('Error syncing logs:', err);
        }
    }, []);

    return { dailyLog, setDailyLog: updateDailyLog, habits, setHabits: updateHabits, loading, error };
}
