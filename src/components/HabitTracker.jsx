import React, { useState, useEffect } from 'react';
import { Check, Plus, Trash2, Sparkles } from 'lucide-react';
import { cn } from '../lib/utils';

const DEFAULT_HABITS = [
    { id: 'caffeine', label: 'No caffeine after 2 PM' },
    { id: 'screens', label: 'No screens 1h before bed' },
    { id: 'read', label: 'Read a book' },
    { id: 'magnesium', label: 'Took Magnesium' },
    { id: 'meditation', label: 'Meditation (10m)' },
    { id: 'hot_shower', label: 'Hot shower/bath' },
];

export function HabitTracker({ habits, setHabits, dailyLog, setDailyLog }) {
    const [newHabit, setNewHabit] = useState('');
    const today = new Date().toISOString().split('T')[0];

    // Initialize today's log if not present
    useEffect(() => {
        if (!dailyLog[today]) {
            setDailyLog(prev => ({
                ...prev,
                [today]: { habits: [], sleepScore: null, notes: '' }
            }));
        }
    }, [today, dailyLog, setDailyLog]);

    const toggleHabit = (habitId) => {
        const currentHabits = dailyLog[today]?.habits || [];
        const isCompleted = currentHabits.includes(habitId);

        const updatedHabits = isCompleted
            ? currentHabits.filter(id => id !== habitId)
            : [...currentHabits, habitId];

        setDailyLog(prev => ({
            ...prev,
            [today]: { ...prev[today], habits: updatedHabits }
        }));
    };

    const addNewHabit = (e) => {
        e.preventDefault();
        if (!newHabit.trim()) return;

        const id = newHabit.toLowerCase().replace(/\s+/g, '_');
        setHabits(prev => [...prev, { id, label: newHabit }]);
        setNewHabit('');
    };

    const removeHabit = (id) => {
        setHabits(prev => prev.filter(h => h.id !== id));
    };

    const completedCount = dailyLog[today]?.habits?.length || 0;
    const totalCount = habits.length;
    const progress = totalCount > 0 ? (completedCount / totalCount) * 100 : 0;

    return (
        <div className="space-y-8">
            <div className="space-y-2">
                <h2 className="text-2xl font-bold text-white">Today's Rituals</h2>
                <p className="text-zinc-400">Tick off what you've done today to prepare for a good sleep.</p>
            </div>

            {/* Progress Card */}
            <div className="p-6 rounded-3xl bg-gradient-to-br from-indigo-900/50 to-purple-900/20 border border-indigo-500/20 relative overflow-hidden group">
                <div className="absolute inset-0 bg-grid-white/5 [mask-image:linear-gradient(0deg,white,rgba(255,255,255,0.6))] -z-10" />
                <div className="flex items-center justify-between mb-4 relative z-10">
                    <div>
                        <div className="text-3xl font-bold text-white mb-1">{Math.round(progress)}%</div>
                        <div className="text-indigo-200 text-sm font-medium">Consistency Score</div>
                    </div>
                    <div className="p-3 bg-indigo-500/20 rounded-2xl text-indigo-300">
                        <Sparkles className="w-6 h-6" />
                    </div>
                </div>
                <div className="h-2 bg-zinc-900/50 rounded-full overflow-hidden">
                    <div
                        className="h-full bg-gradient-to-r from-indigo-500 to-purple-500 transition-all duration-1000 ease-out"
                        style={{ width: `${progress}%` }}
                    />
                </div>
            </div>

            {/* Habits List */}
            <div className="grid gap-3">
                {habits.map(habit => {
                    const isCompleted = dailyLog[today]?.habits?.includes(habit.id);
                    return (
                        <button
                            key={habit.id}
                            onClick={() => toggleHabit(habit.id)}
                            className={cn(
                                "group flex items-center justify-between p-4 rounded-2xl border transition-all duration-300",
                                isCompleted
                                    ? "bg-indigo-500/10 border-indigo-500/50 shadow-[0_0_20px_-5px_rgba(99,102,241,0.3)]"
                                    : "bg-zinc-900/50 border-zinc-800 hover:bg-zinc-800 hover:border-zinc-700"
                            )}
                        >
                            <div className="flex items-center gap-4">
                                <div className={cn(
                                    "w-6 h-6 rounded-full border-2 flex items-center justify-center transition-all duration-300",
                                    isCompleted
                                        ? "bg-indigo-500 border-indigo-500 scale-110"
                                        : "border-zinc-600 group-hover:border-zinc-500"
                                )}>
                                    {isCompleted && <Check className="w-3.5 h-3.5 text-white stroke-[3]" />}
                                </div>
                                <span className={cn(
                                    "font-medium transition-colors",
                                    isCompleted ? "text-white" : "text-zinc-400 group-hover:text-zinc-200"
                                )}>
                                    {habit.label}
                                </span>
                            </div>

                            <div
                                onClick={(e) => { e.stopPropagation(); removeHabit(habit.id); }}
                                className="opacity-0 group-hover:opacity-100 p-2 text-zinc-600 hover:text-red-400 transition-all"
                            >
                                <Trash2 className="w-4 h-4" />
                            </div>
                        </button>
                    );
                })}
            </div>

            {/* Add New Habit */}
            <form onSubmit={addNewHabit} className="flex gap-3">
                <input
                    type="text"
                    value={newHabit}
                    onChange={(e) => setNewHabit(e.target.value)}
                    placeholder="Add a new habit..."
                    className="flex-1 bg-zinc-900/50 border border-zinc-800 rounded-xl px-4 py-3 text-zinc-200 placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all"
                />
                <button
                    type="submit"
                    disabled={!newHabit.trim()}
                    className="bg-zinc-800 hover:bg-zinc-700 text-zinc-200 p-3 rounded-xl transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    <Plus className="w-6 h-6" />
                </button>
            </form>
        </div>
    );
}
