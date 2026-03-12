import React, { useState } from 'react';
import { Calendar, Moon, Save } from 'lucide-react';
import { cn } from '../lib/utils';
import { toast } from 'sonner';

function formatFormValue(value) {
    return value === null || value === undefined ? '' : String(value);
}

function buildFormState(entry) {
    return {
        score: formatFormValue(entry?.sleepScore),
        notes: entry?.notes || '',
        bedtime: entry?.bedtime || '',
        waketime: entry?.waketime || '',
        durationHours: formatFormValue(entry?.durationHours),
        durationMinutes: formatFormValue(entry?.durationMinutes),
        deepHours: formatFormValue(entry?.deepHours),
        deepMinutes: formatFormValue(entry?.deepMinutes),
        bodyBattery: formatFormValue(entry?.bodyBattery),
        hrv: formatFormValue(entry?.hrv),
        rhr: formatFormValue(entry?.rhr),
    };
}

function calculateDuration(bedtime, waketime) {
    if (!bedtime || !waketime) {
        return null;
    }

    const [bedH, bedM] = bedtime.split(':').map(Number);
    const [wakeH, wakeM] = waketime.split(':').map(Number);

    let diffMinutes = (wakeH * 60 + wakeM) - (bedH * 60 + bedM);
    if (diffMinutes < 0) {
        diffMinutes += 24 * 60;
    }

    return {
        durationHours: String(Math.floor(diffMinutes / 60)),
        durationMinutes: String(diffMinutes % 60),
    };
}

export function SleepEntry({ dailyLog, setDailyLog, onSave, selectedDate }) {
    const date = selectedDate;
    const [drafts, setDrafts] = useState({});
    const [savedDate, setSavedDate] = useState(null);

    const form = drafts[date] ?? buildFormState(dailyLog[date]);
    const saved = savedDate === date;

    const updateForm = (updates) => {
        setDrafts((prev) => {
            const base = prev[date] ?? buildFormState(dailyLog[date]);
            return {
                ...prev,
                [date]: {
                    ...base,
                    ...updates,
                },
            };
        });
    };

    const updateTimeField = (field, value) => {
        const nextForm = {
            ...(drafts[date] ?? buildFormState(dailyLog[date])),
            [field]: value,
        };
        const duration = calculateDuration(nextForm.bedtime, nextForm.waketime);

        if (duration) {
            nextForm.durationHours = duration.durationHours;
            nextForm.durationMinutes = duration.durationMinutes;
        }

        setDrafts((prev) => ({
            ...prev,
            [date]: nextForm,
        }));
    };

    const handleSave = (e) => {
        e.preventDefault();

        setDailyLog((prev) => ({
            ...prev,
            [date]: {
                ...(prev[date] || { habits: [] }),
                sleepScore: parseInt(form.score, 10),
                bedtime: form.bedtime,
                waketime: form.waketime,
                durationHours: parseInt(form.durationHours, 10) || 0,
                durationMinutes: parseInt(form.durationMinutes, 10) || 0,
                deepHours: parseInt(form.deepHours, 10) || 0,
                deepMinutes: parseInt(form.deepMinutes, 10) || 0,
                bodyBattery: parseInt(form.bodyBattery, 10) || 0,
                hrv: parseInt(form.hrv, 10) || 0,
                rhr: parseInt(form.rhr, 10) || 0,
                notes: form.notes,
            }
        }));

        setSavedDate(date);
        toast.success('Sleep entry saved successfully!');
        setTimeout(() => {
            setSavedDate((current) => (current === date ? null : current));
            onSave?.();
        }, 1500);
    };

    return (
        <div className="space-y-8 pb-20">
            <div className="space-y-2">
                <h2 className="text-2xl font-bold text-white">Log Sleep</h2>
                <p className="text-zinc-400">Enter your Garmin stats for the night.</p>
            </div>

            <form onSubmit={handleSave} className="space-y-8">
                {/* Date Display (Read-only, controlled by global picker) */}
                <div className="space-y-2">
                    <label className="text-sm font-medium text-zinc-400 ml-1">Date</label>
                    <div className="relative">
                        <Calendar className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-zinc-500" />
                        <div className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl pl-12 pr-4 py-4 text-zinc-500 cursor-not-allowed">
                            {date} <span className="text-xs ml-2">(Change in header)</span>
                        </div>
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
                                    value={form.score}
                                    onChange={(e) => updateForm({ score: e.target.value })}
                                    placeholder="85"
                                    className="w-full bg-zinc-900/80 border border-zinc-800 rounded-2xl pl-12 pr-4 py-6 text-4xl font-bold text-white placeholder:text-zinc-700 focus:outline-none focus:border-indigo-500/50 transition-all"
                                />
                                <span className="absolute right-6 text-zinc-600 font-medium">/ 100</span>
                            </div>
                        </div>
                    </div>

                    {/* Bedtime & Waketime */}
                    <div className="col-span-2 grid grid-cols-2 gap-4">
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-zinc-400 ml-1">Bedtime</label>
                            <input
                                type="time"
                                value={form.bedtime}
                                onChange={(e) => updateTimeField('bedtime', e.target.value)}
                                className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl px-4 py-4 text-xl font-bold text-white focus:outline-none focus:border-indigo-500/50 transition-all text-center [color-scheme:dark]"
                            />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-zinc-400 ml-1">Waketime</label>
                            <input
                                type="time"
                                value={form.waketime}
                                onChange={(e) => updateTimeField('waketime', e.target.value)}
                                className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl px-4 py-4 text-xl font-bold text-white focus:outline-none focus:border-indigo-500/50 transition-all text-center [color-scheme:dark]"
                            />
                        </div>
                    </div>

                    {/* Duration */}
                    <div className="col-span-2 space-y-2">
                        <label className="text-sm font-medium text-zinc-400 ml-1">Duration (Auto-calc)</label>
                        <div className="flex gap-2">
                            <div className="relative flex-1">
                                <input
                                    type="number"
                                    min="0"
                                    max="24"
                                    value={form.durationHours}
                                    onChange={(e) => updateForm({ durationHours: e.target.value })}
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
                                    value={form.durationMinutes}
                                    onChange={(e) => updateForm({ durationMinutes: e.target.value })}
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
                                    value={form.deepHours}
                                    onChange={(e) => updateForm({ deepHours: e.target.value })}
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
                                    value={form.deepMinutes}
                                    onChange={(e) => updateForm({ deepMinutes: e.target.value })}
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
                                value={form.bodyBattery}
                                onChange={(e) => updateForm({ bodyBattery: e.target.value })}
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
                                value={form.hrv}
                                onChange={(e) => updateForm({ hrv: e.target.value })}
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
                                value={form.rhr}
                                onChange={(e) => updateForm({ rhr: e.target.value })}
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
                        value={form.notes}
                        onChange={(e) => updateForm({ notes: e.target.value })}
                        placeholder="Woke up once, felt refreshed..."
                        rows={3}
                        className="w-full bg-zinc-900/50 border border-zinc-800 rounded-2xl p-4 text-zinc-200 placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all resize-none"
                    />
                </div>

                <button
                    type="submit"
                    disabled={!form.score}
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
