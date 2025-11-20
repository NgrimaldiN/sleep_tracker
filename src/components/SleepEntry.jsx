import React, { useState, useEffect } from 'react';
import { Calendar, Moon, Star, Save } from 'lucide-react';
import { cn } from '../lib/utils';

export function SleepEntry({ dailyLog, setDailyLog, setActiveTab }) {
    // Default to yesterday since we usually log sleep for the previous night
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const defaultDate = yesterday.toISOString().split('T')[0];

    const [date, setDate] = useState(defaultDate);
    const [score, setScore] = useState('');
    const [notes, setNotes] = useState('');
    const [saved, setSaved] = useState(false);
    const [durationHours, setDurationHours] = useState('');
    const [durationMinutes, setDurationMinutes] = useState('');
    const [deepHours, setDeepHours] = useState('');
    const [deepMinutes, setDeepMinutes] = useState('');
    const [bodyBattery, setBodyBattery] = useState('');
    const [hrv, setHrv] = useState('');
    const [rhr, setRhr] = useState('');

    // Load existing data for selected date
    useEffect(() => {
        const existing = dailyLog[date];
        if (existing) {
            setScore(existing.sleepScore || '');
            setNotes(existing.notes || '');
            setDurationHours(existing.durationHours || '');
            setDurationMinutes(existing.durationMinutes || '');
            setDeepHours(existing.deepHours || '');
            setDeepMinutes(existing.deepMinutes || '');
            setBodyBattery(existing.bodyBattery || '');
            setHrv(existing.hrv || '');
            setRhr(existing.rhr || '');
        } else {
            setScore('');
            setNotes('');
            setDurationHours('');
            setDurationMinutes('');
            setDeepHours('');
            setDeepMinutes('');
            setBodyBattery('');
            setHrv('');
            setRhr('');
        }
        setSaved(false);
    }, [date, dailyLog]);

    const handleSave = (e) => {
        e.preventDefault();

        setDailyLog(prev => ({
            ...prev,
            [date]: {
                ...(prev[date] || { habits: [] }),
                sleepScore: parseInt(score),
                durationHours: parseInt(durationHours) || 0,
                durationMinutes: parseInt(durationMinutes) || 0,
                deepHours: parseInt(deepHours) || 0,
                deepMinutes: parseInt(deepMinutes) || 0,
                bodyBattery: parseInt(bodyBattery) || 0,
                hrv: parseInt(hrv) || 0,
                rhr: parseInt(rhr) || 0,
                notes
            }
        }));

        setSaved(true);
        setTimeout(() => {
            setSaved(false);
            setActiveTab('dashboard');
        }, 1500);
    };

    return (
        <div className="space-y-8 pb-20">
            <div className="space-y-2">
                <h2 className="text-2xl font-bold text-white">Log Sleep</h2>
                <p className="text-zinc-400">Enter your Garmin stats for the night.</p>
            </div>

            <form onSubmit={handleSave} className="space-y-8">
                {/* Date Picker */}
                <div className="space-y-2">
                    <label className="text-sm font-medium text-zinc-400 ml-1">Date</label>
                    <div className="relative">
                        <Calendar className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-zinc-500" />
                        <input
                            type="date"
                            value={date}
                            onChange={(e) => setDate(e.target.value)}
                            className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl pl-12 pr-4 py-4 text-zinc-200 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all [color-scheme:dark]"
                        />
                    </div>
                </div>

                {/* Main Metrics Grid */}
                <div className="grid grid-cols-2 gap-4">
                    {/* Sleep Score */}
                    <div className="col-span-2 space-y-2">
                        <label className="text-sm font-medium text-zinc-400 ml-1">Sleep Score</label>
                        <div className="relative group">
                            <div className="absolute inset-0 bg-indigo-500/20 blur-xl rounded-full opacity-0 group-focus-within:opacity-100 transition-opacity duration-500" />
                            <div className="relative flex items-center">
                                <Moon className="absolute left-4 w-5 h-5 text-indigo-400" />
                                <input
                                    type="number"
                                    min="0"
                                    max="100"
                                    value={score}
                                    onChange={(e) => setScore(e.target.value)}
                                    placeholder="85"
                                    className="w-full bg-zinc-900/80 border border-zinc-800 rounded-2xl pl-12 pr-4 py-6 text-4xl font-bold text-white placeholder:text-zinc-700 focus:outline-none focus:border-indigo-500/50 transition-all"
                                />
                                <span className="absolute right-6 text-zinc-600 font-medium">/ 100</span>
                            </div>
                        </div>
                    </div>

                    {/* Duration */}
                    <div className="col-span-2 space-y-2">
                        <label className="text-sm font-medium text-zinc-400 ml-1">Duration</label>
                        <div className="flex gap-2">
                            <div className="relative flex-1">
                                <input
                                    type="number"
                                    min="0"
                                    max="24"
                                    value={durationHours}
                                    onChange={(e) => setDurationHours(e.target.value)}
                                    placeholder="7"
                                    className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl px-4 py-4 text-xl font-bold text-white placeholder:text-zinc-700 focus:outline-none focus:border-indigo-500/50 transition-all text-center"
                                />
                                <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-zinc-500 font-medium">hr</span>
                            </div>
                            <div className="relative flex-1">
                                <input
                                    type="number"
                                    min="0"
                                    max="59"
                                    value={durationMinutes}
                                    onChange={(e) => setDurationMinutes(e.target.value)}
                                    placeholder="30"
                                    className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl px-4 py-4 text-xl font-bold text-white placeholder:text-zinc-700 focus:outline-none focus:border-indigo-500/50 transition-all text-center"
                                />
                                <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-zinc-500 font-medium">min</span>
                            </div>
                        </div>
                    </div>

                    {/* Deep Sleep */}
                    <div className="col-span-2 space-y-2">
                        <label className="text-sm font-medium text-zinc-400 ml-1">Deep Sleep</label>
                        <div className="flex gap-2">
                            <div className="relative flex-1">
                                <input
                                    type="number"
                                    min="0"
                                    max="24"
                                    value={deepHours}
                                    onChange={(e) => setDeepHours(e.target.value)}
                                    placeholder="1"
                                    className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl px-4 py-4 text-xl font-bold text-white placeholder:text-zinc-700 focus:outline-none focus:border-indigo-500/50 transition-all text-center"
                                />
                                <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-zinc-500 font-medium">hr</span>
                            </div>
                            <div className="relative flex-1">
                                <input
                                    type="number"
                                    min="0"
                                    max="59"
                                    value={deepMinutes}
                                    onChange={(e) => setDeepMinutes(e.target.value)}
                                    placeholder="20"
                                    className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl px-4 py-4 text-xl font-bold text-white placeholder:text-zinc-700 focus:outline-none focus:border-indigo-500/50 transition-all text-center"
                                />
                                <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-zinc-500 font-medium">min</span>
                            </div>
                        </div>
                    </div>

                    {/* Body Battery */}
                    <div className="space-y-2">
                        <label className="text-sm font-medium text-zinc-400 ml-1">Body Batt.</label>
                        <div className="relative">
                            <input
                                type="number"
                                min="0"
                                max="100"
                                value={bodyBattery}
                                onChange={(e) => setBodyBattery(e.target.value)}
                                placeholder="80"
                                className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl px-4 py-4 text-xl font-bold text-white placeholder:text-zinc-700 focus:outline-none focus:border-indigo-500/50 transition-all"
                            />
                        </div>
                    </div>

                    {/* HRV */}
                    <div className="space-y-2">
                        <label className="text-sm font-medium text-zinc-400 ml-1">HRV (ms)</label>
                        <div className="relative">
                            <input
                                type="number"
                                value={hrv}
                                onChange={(e) => setHrv(e.target.value)}
                                placeholder="45"
                                className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl px-4 py-4 text-xl font-bold text-white placeholder:text-zinc-700 focus:outline-none focus:border-indigo-500/50 transition-all"
                            />
                        </div>
                    </div>

                    {/* Resting HR */}
                    <div className="space-y-2">
                        <label className="text-sm font-medium text-zinc-400 ml-1">RHR (bpm)</label>
                        <div className="relative">
                            <input
                                type="number"
                                value={rhr}
                                onChange={(e) => setRhr(e.target.value)}
                                placeholder="55"
                                className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl px-4 py-4 text-xl font-bold text-white placeholder:text-zinc-700 focus:outline-none focus:border-indigo-500/50 transition-all"
                            />
                        </div>
                    </div>
                </div>

                {/* Notes */}
                <div className="space-y-2">
                    <label className="text-sm font-medium text-zinc-400 ml-1">Notes</label>
                    <textarea
                        value={notes}
                        onChange={(e) => setNotes(e.target.value)}
                        placeholder="Woke up once, felt refreshed..."
                        rows={3}
                        className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl p-4 text-zinc-200 placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all resize-none"
                    />
                </div>

                <button
                    type="submit"
                    disabled={!score}
                    className={cn(
                        "w-full py-4 rounded-2xl font-bold text-lg flex items-center justify-center gap-2 transition-all duration-300",
                        saved
                            ? "bg-green-500/20 text-green-400 ring-1 ring-green-500/50"
                            : "bg-indigo-600 hover:bg-indigo-500 text-white shadow-lg shadow-indigo-900/20 hover:shadow-indigo-900/40"
                    )}
                >
                    {saved ? (
                        <>
                            <CheckIcon className="w-5 h-5" />
                            Saved!
                        </>
                    ) : (
                        <>
                            <Save className="w-5 h-5" />
                            Save Entry
                        </>
                    )}
                </button>
            </form>
        </div>
    );
}

function CheckIcon({ className }) {
    return (
        <svg
            className={className}
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={3}
        >
            <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
        </svg>
    );
}
