import React, { useMemo, useState } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar, Cell } from 'recharts';
import { Trophy, TrendingUp, Activity, Battery, Clock, Heart } from 'lucide-react';
import { cn } from '../lib/utils';

const METRICS = {
    sleepScore: { label: 'Sleep Score', color: '#8b5cf6', icon: MoonIcon, unit: '' },
    duration: { label: 'Duration', color: '#3b82f6', icon: Clock, unit: 'h' },
    deepSleep: { label: 'Deep Sleep', color: '#0ea5e9', icon: Activity, unit: 'h' },
    bodyBattery: { label: 'Body Battery', color: '#f59e0b', icon: Battery, unit: '' },
    hrv: { label: 'HRV', color: '#10b981', icon: Heart, unit: 'ms' },
    rhr: { label: 'Resting HR', color: '#ef4444', icon: Heart, unit: 'bpm' },
};

function MoonIcon({ className }) {
    return (
        <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
        </svg>
    );
}

export function Dashboard({ dailyLog, habits }) {
    const [selectedMetric, setSelectedMetric] = useState('sleepScore');

    const stats = useMemo(() => {
        const entries = Object.entries(dailyLog)
            .map(([date, data]) => {
                // Calculate decimal hours for duration and deep sleep
                const duration = (data.durationHours || 0) + (data.durationMinutes || 0) / 60;
                const deepSleep = (data.deepHours || 0) + (data.deepMinutes || 0) / 60;

                return {
                    date,
                    ...data,
                    duration: parseFloat(duration.toFixed(1)),
                    deepSleep: parseFloat(deepSleep.toFixed(1))
                };
            })
            .filter(entry => entry.sleepScore !== null && entry.sleepScore !== undefined)
            .sort((a, b) => new Date(a.date) - new Date(b.date));

        if (entries.length === 0) return null;

        // Calculate correlation between habits and selected metric
        const habitStats = habits.map(habit => {
            const withHabit = entries.filter(e => e.habits?.includes(habit.id));
            const withoutHabit = entries.filter(e => !e.habits?.includes(habit.id));

            const getAvg = (arr) => arr.length
                ? arr.reduce((acc, curr) => acc + (curr[selectedMetric] || 0), 0) / arr.length
                : 0;

            const avgWith = getAvg(withHabit);
            const avgWithout = getAvg(withoutHabit);

            return {
                ...habit,
                avgScore: avgWith,
                impact: avgWith - avgWithout,
                count: withHabit.length
            };
        }).filter(h => h.count > 0).sort((a, b) => b.avgScore - a.avgScore);

        const recentAvg = entries.slice(-7).reduce((acc, curr) => acc + (curr[selectedMetric] || 0), 0) / Math.min(entries.length, 7);
        const bestHabit = habitStats[0];

        return {
            entries,
            habitStats,
            recentAvg,
            bestHabit
        };
    }, [dailyLog, habits, selectedMetric]);

    if (!stats) {
        return (
            <div className="flex flex-col items-center justify-center h-[60vh] text-center space-y-4">
                <div className="p-4 bg-zinc-900 rounded-full">
                    <TrendingUp className="w-8 h-8 text-zinc-600" />
                </div>
                <div>
                    <h3 className="text-xl font-bold text-zinc-200">No Data Yet</h3>
                    <p className="text-zinc-500 max-w-xs mx-auto mt-2">Start logging your sleep and habits to see insights here.</p>
                </div>
            </div>
        );
    }

    const MetricIcon = METRICS[selectedMetric].icon;

    return (
        <div className="space-y-8 pb-20">
            <div className="space-y-2">
                <h2 className="text-2xl font-bold text-white">Insights</h2>
                <p className="text-zinc-400">Analyze your sleep metrics.</p>
            </div>

            {/* Metric Selector */}
            <div className="flex gap-2 overflow-x-auto pb-2 no-scrollbar">
                {Object.entries(METRICS).map(([key, config]) => {
                    const Icon = config.icon;
                    const isSelected = selectedMetric === key;
                    return (
                        <button
                            key={key}
                            onClick={() => setSelectedMetric(key)}
                            className={cn(
                                "flex items-center gap-2 px-4 py-2 rounded-xl border transition-all whitespace-nowrap",
                                isSelected
                                    ? "bg-zinc-800 border-zinc-700 text-white"
                                    : "bg-zinc-900/50 border-zinc-800 text-zinc-500 hover:bg-zinc-800/50"
                            )}
                        >
                            <Icon className={cn("w-4 h-4", isSelected ? "text-indigo-400" : "text-zinc-600")} />
                            <span className="text-sm font-medium">{config.label}</span>
                        </button>
                    );
                })}
            </div>

            {/* Key Stats Row */}
            <div className="grid grid-cols-2 gap-4">
                <div className="p-5 rounded-2xl bg-zinc-900/50 border border-zinc-800">
                    <div className="text-zinc-400 text-xs font-medium uppercase tracking-wider mb-1">7-Day Avg</div>
                    <div className="flex items-baseline gap-1">
                        <div className="text-3xl font-bold text-white">
                            {selectedMetric === 'duration' || selectedMetric === 'deepSleep'
                                ? stats.recentAvg.toFixed(1)
                                : Math.round(stats.recentAvg)}
                        </div>
                        <span className="text-sm text-zinc-500 font-medium">{METRICS[selectedMetric].unit}</span>
                    </div>
                </div>
                <div className="p-5 rounded-2xl bg-zinc-900/50 border border-zinc-800">
                    <div className="text-zinc-400 text-xs font-medium uppercase tracking-wider mb-1">Entries</div>
                    <div className="text-3xl font-bold text-white">{stats.entries.length}</div>
                </div>
            </div>

            {/* Best Habit Card */}
            {stats.bestHabit && (
                <div className="p-6 rounded-3xl bg-gradient-to-br from-emerald-900/20 to-teal-900/10 border border-emerald-500/20 relative overflow-hidden">
                    <div className="flex items-start justify-between relative z-10">
                        <div>
                            <div className="flex items-center gap-2 mb-2">
                                <Trophy className="w-5 h-5 text-emerald-400" />
                                <span className="text-emerald-200 font-medium">Top Performer</span>
                            </div>
                            <h3 className="text-xl font-bold text-white mb-1">{stats.bestHabit.label}</h3>
                            <p className="text-emerald-200/60 text-sm">
                                Avg {METRICS[selectedMetric].label}: <span className="text-white font-bold">
                                    {selectedMetric === 'duration' || selectedMetric === 'deepSleep'
                                        ? stats.bestHabit.avgScore.toFixed(1)
                                        : Math.round(stats.bestHabit.avgScore)}
                                    {METRICS[selectedMetric].unit}
                                </span>
                            </p>
                        </div>
                    </div>
                </div>
            )}

            {/* Trend Chart */}
            <div className="p-6 rounded-3xl bg-zinc-900/50 border border-zinc-800">
                <h3 className="text-lg font-bold text-white mb-6">{METRICS[selectedMetric].label} Trend</h3>
                <div className="h-64 w-full">
                    <ResponsiveContainer width="100%" height="100%">
                        <LineChart data={stats.entries}>
                            <defs>
                                <linearGradient id="lineGradient" x1="0" y1="0" x2="1" y2="0">
                                    <stop offset="0%" stopColor={METRICS[selectedMetric].color} />
                                    <stop offset="100%" stopColor={METRICS[selectedMetric].color} stopOpacity={0.5} />
                                </linearGradient>
                            </defs>
                            <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                            <XAxis
                                dataKey="date"
                                stroke="#52525b"
                                tickFormatter={(d) => new Date(d).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
                                tick={{ fontSize: 12 }}
                                tickLine={false}
                                axisLine={false}
                                dy={10}
                            />
                            <YAxis
                                stroke="#52525b"
                                tick={{ fontSize: 12 }}
                                tickLine={false}
                                axisLine={false}
                                dx={-10}
                            />
                            <Tooltip
                                contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '12px' }}
                                itemStyle={{ color: '#fff' }}
                                labelStyle={{ color: '#a1a1aa', marginBottom: '4px' }}
                                formatter={(value) => [
                                    `${value} ${METRICS[selectedMetric].unit}`,
                                    METRICS[selectedMetric].label
                                ]}
                            />
                            <Line
                                type="monotone"
                                dataKey={selectedMetric}
                                stroke={METRICS[selectedMetric].color}
                                strokeWidth={3}
                                dot={{ fill: '#18181b', stroke: METRICS[selectedMetric].color, strokeWidth: 2, r: 4 }}
                                activeDot={{ r: 6, fill: '#fff' }}
                            />
                        </LineChart>
                    </ResponsiveContainer>
                </div>
            </div>

            {/* Habit Impact Chart */}
            {stats.habitStats.length > 0 && (
                <div className="p-6 rounded-3xl bg-zinc-900/50 border border-zinc-800">
                    <h3 className="text-lg font-bold text-white mb-6">Habit Impact on {METRICS[selectedMetric].label}</h3>
                    <div className="h-64 w-full">
                        <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={stats.habitStats} layout="vertical" margin={{ left: 0, right: 30 }}>
                                <CartesianGrid strokeDasharray="3 3" stroke="#27272a" horizontal={false} />
                                <XAxis type="number" hide />
                                <YAxis
                                    dataKey="label"
                                    type="category"
                                    width={100}
                                    tick={{ fill: '#a1a1aa', fontSize: 11 }}
                                    tickLine={false}
                                    axisLine={false}
                                />
                                <Tooltip
                                    cursor={{ fill: '#27272a' }}
                                    contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '12px' }}
                                    itemStyle={{ color: '#fff' }}
                                    formatter={(value) => [
                                        `${typeof value === 'number' ? value.toFixed(1) : value} ${METRICS[selectedMetric].unit}`,
                                        'Average'
                                    ]}
                                />
                                <Bar dataKey="avgScore" radius={[0, 4, 4, 0]} barSize={20}>
                                    {stats.habitStats.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={METRICS[selectedMetric].color} />
                                    ))}
                                </Bar>
                            </BarChart>
                        </ResponsiveContainer>
                    </div>
                </div>
            )}
        </div>
    );
}
