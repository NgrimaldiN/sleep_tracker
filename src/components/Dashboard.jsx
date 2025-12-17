import React, { useMemo, useState } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar, Cell } from 'recharts';
import { Trophy, TrendingUp, Activity, Battery, Clock, Heart } from 'lucide-react';
import { cn } from '../lib/utils';

const METRICS = {
    sleepScore: { label: 'Sleep Score', color: '#8b5cf6', icon: MoonIcon, unit: '', inverse: false },
    duration: { label: 'Duration', color: '#3b82f6', icon: Clock, unit: 'h', inverse: false },
    deepSleep: { label: 'Deep Sleep', color: '#0ea5e9', icon: Activity, unit: 'h', inverse: false },
    bodyBattery: { label: 'Body Battery', color: '#f59e0b', icon: Battery, unit: '', inverse: false },
    hrv: { label: 'HRV', color: '#10b981', icon: Heart, unit: 'ms', inverse: false },
    rhr: { label: 'Resting HR', color: '#ef4444', icon: Heart, unit: 'bpm', inverse: true },
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

        // Calculate Impact Scores
        const habitImpacts = habits.flatMap(habit => {
            if (habit.type === 'select' && habit.options) {
                // Create a virtual habit for each option
                return habit.options.map(option => {
                    const withOption = entries.filter(e => e.habitValues?.[habit.id] === option);
                    const withoutOption = entries.filter(e => e.habitValues?.[habit.id] !== option);

                    if (withOption.length === 0 && withoutOption.length === 0) return null;

                    const getAvg = (arr) => arr.length
                        ? arr.reduce((acc, curr) => acc + (curr[selectedMetric] || 0), 0) / arr.length
                        : 0;

                    const avgWith = withOption.length ? getAvg(withOption) : 0;
                    const avgWithout = withoutOption.length ? getAvg(withoutOption) : 0;

                    let impact = 0;
                    let isSignificant = false;


                    if (withOption.length > 0 && withoutOption.length > 0) {
                        impact = avgWith - avgWithout;
                        isSignificant = true;
                    }

                    // ENFORCE MINIMUM THRESHOLD for Select Options
                    if (withOption.length < 3) {
                        isSignificant = false;
                    }

                    return {
                        id: `${habit.id}_${option}`,
                        label: `${habit.label}: ${option}`,
                        avgWith,
                        avgWithout,
                        impact,
                        isSignificant,
                        countWith: withOption.length,
                        countWithout: withoutOption.length,
                        avgValue: null // No avg value for select options
                    };
                });
            }

            // Standard logic for boolean/number/time
            const withHabit = entries.filter(e => e.habits?.includes(habit.id));
            const withoutHabit = entries.filter(e => !e.habits?.includes(habit.id));

            const getAvg = (arr) => arr.length
                ? arr.reduce((acc, curr) => acc + (curr[selectedMetric] || 0), 0) / arr.length
                : 0;

            let avgWith = withHabit.length ? getAvg(withHabit) : 0;
            let avgWithout = withoutHabit.length ? getAvg(withoutHabit) : 0;
            let impact = 0;
            let isSignificant = false;
            let labelDetail = '';

            // Check if we have enough data for standard "With vs Without" comparison
            if (withHabit.length > 0 && withoutHabit.length > 0) {
                impact = avgWith - avgWithout;
                isSignificant = true;
            }
            // If not enough "without" data, but we have numeric/time data, try "High vs Low" or "Late vs Early"
            else if ((habit.type === 'number' || habit.type === 'time') && withHabit.length >= 4) {
                const values = withHabit
                    .map(e => ({ entry: e, value: parseFloat(e.habitValues?.[habit.id]) }))
                    .filter(item => !isNaN(item.value))
                    .sort((a, b) => a.value - b.value);

                if (values.length >= 4) {
                    const medianIndex = Math.floor(values.length / 2);
                    const median = values[medianIndex].value;

                    const groupA = values.filter(v => v.value <= median); // Low / Early
                    const groupB = values.filter(v => v.value > median);  // High / Late

                    // For time, we might want to handle it differently if it crosses midnight, but simple sort works for now if format becomes comparable number
                    // Assuming time is handled as string in DB, parseFloat might be NaN. 
                    // If type is time, values are likely strings "HH:MM".

                    if (habit.type === 'time') {
                        // Re-process for Time
                        const timeValues = withHabit
                            .map(e => {
                                const val = e.habitValues?.[habit.id];
                                if (!val) return null;
                                const [h, m] = val.split(':').map(Number);
                                // Normalize for sorting (create value 0-24 or similar)
                                // If hours < 5 (late night), treat as next day (add 24)
                                let sortVal = h + m / 60;
                                if (sortVal < 5) sortVal += 24;
                                return { entry: e, value: sortVal, display: val };
                            })
                            .filter(Boolean)
                            .sort((a, b) => a.value - b.value);

                        if (timeValues.length >= 4) {
                            const tMedianIndex = Math.floor(timeValues.length / 2);
                            const tMedian = timeValues[tMedianIndex].value;

                            const tGroupA = timeValues.filter(v => v.value <= tMedian); // Early
                            const tGroupB = timeValues.filter(v => v.value > tMedian);  // Late

                            if (tGroupA.length > 0 && tGroupB.length > 0) {
                                const avgA = getAvg(tGroupA.map(v => v.entry));
                                const avgB = getAvg(tGroupB.map(v => v.entry));

                                impact = avgB - avgA;
                                isSignificant = true;
                                avgWith = avgB; // Show Avg for "Late" group
                                avgWithout = avgA; // Show Avg for "Early" group
                                labelDetail = '(Late vs Early)';
                            }
                        }
                    } else if (groupA.length > 0 && groupB.length > 0) {
                        // Numeric
                        const avgA = getAvg(groupA.map(v => v.entry));
                        const avgB = getAvg(groupB.map(v => v.entry));

                        impact = avgB - avgA;
                        isSignificant = true;
                        avgWith = avgB; // Show Avg for "High" group
                        avgWithout = avgA; // Show Avg for "Low" group
                        labelDetail = '(High vs Low)';
                    }
                }
            }

            // ENFORCE MINIMUM THRESHOLD: Need at least 3 days of "with habit" data
            if (withHabit.length < 3) {
                isSignificant = false;
            }

            if (!isSignificant && withHabit.length === 0 && withoutHabit.length === 0) return null;

            let avgValue = null;
            if (habit.type === 'number' && withHabit.length > 0) {
                avgValue = withHabit.reduce((acc, curr) => acc + (curr.habitValues?.[habit.id] || 0), 0) / withHabit.length;
            }

            return {
                ...habit,
                avgWith,
                avgWithout,
                impact,
                isSignificant,
                countWith: withHabit.length,
                countWithout: withoutHabit.length,
                avgValue,
                labelDetail
            };
        }).flat().filter(Boolean).sort((a, b) => {
            // Prioritize significant items first
            if (a.isSignificant && !b.isSignificant) return -1;
            if (!a.isSignificant && b.isSignificant) return 1;
            // Then sort by impact magnitude
            return Math.abs(b.impact) - Math.abs(a.impact);
        });

        const recentAvg = entries.slice(-7).reduce((acc, curr) => acc + (curr[selectedMetric] || 0), 0) / Math.min(entries.length, 7);

        // Calculate Sleep Debt (last 7 days vs 8h target)
        // Debt = (8 * days) - total_sleep
        const last7Days = entries.slice(-7);
        const totalSleepLast7Days = last7Days.reduce((acc, curr) => acc + (curr.duration || 0), 0);
        const targetSleep = last7Days.length * 8;
        const sleepDebt = targetSleep - totalSleepLast7Days;

        // Calculate Optimal Bedtime
        // Group entries by bedtime hour and find the one with highest avg sleep score
        const bedtimeStats = {};
        entries.forEach(entry => {
            if (entry.bedtime && entry.sleepScore) {
                const hour = parseInt(entry.bedtime.split(':')[0]);
                if (!bedtimeStats[hour]) bedtimeStats[hour] = { totalScore: 0, count: 0 };
                bedtimeStats[hour].totalScore += entry.sleepScore;
                bedtimeStats[hour].count += 1;
            }
        });

        let optimalBedtime = null;
        let maxAvgScore = 0;

        Object.entries(bedtimeStats).forEach(([hour, data]) => {
            const avg = data.totalScore / data.count;
            if (avg > maxAvgScore && data.count >= 2) { // Need at least 2 data points
                maxAvgScore = avg;
                optimalBedtime = `${hour}:00 - ${parseInt(hour) + 1}:00`;
            }
        });

        // Calculate Bedtime Impact
        const bedtimeImpact = {};
        entries.forEach(entry => {
            if (entry.bedtime) {
                const hour = parseInt(entry.bedtime.split(':')[0]);
                // Handle midnight crossing (0, 1, 2 should be after 23)
                const sortKey = hour < 12 ? hour + 24 : hour;

                if (!bedtimeImpact[sortKey]) {
                    bedtimeImpact[sortKey] = {
                        hourLabel: `${hour}h`,
                        total: 0,
                        count: 0
                    };
                }
                bedtimeImpact[sortKey].total += (entry[selectedMetric] || 0);
                bedtimeImpact[sortKey].count += 1;
            }
        });

        const bedtimeData = Object.entries(bedtimeImpact)
            .sort(([keyA], [keyB]) => parseInt(keyA) - parseInt(keyB))
            .map(([_, data]) => ({
                label: data.hourLabel,
                value: parseFloat((data.total / data.count).toFixed(1)),
                count: data.count
            }));

        // Calculate Day of Week Impact
        const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        const dayImpact = {};
        entries.forEach(entry => {
            const date = new Date(entry.date);
            const dayIndex = date.getDay(); // 0 = Sun

            if (!dayImpact[dayIndex]) {
                dayImpact[dayIndex] = { total: 0, count: 0 };
            }
            dayImpact[dayIndex].total += (entry[selectedMetric] || 0);
            dayImpact[dayIndex].count += 1;
        });

        // Reorder to start with Mon (index 1) -> Sun (index 0)
        const orderedDays = [1, 2, 3, 4, 5, 6, 0];
        const dayOfWeekData = orderedDays.map(dayIndex => {
            const data = dayImpact[dayIndex];
            if (!data) return null;
            return {
                label: days[dayIndex],
                value: parseFloat((data.total / data.count).toFixed(1)),
                count: data.count
            };
        }).filter(Boolean);

        return {
            entries,
            habitImpacts,
            recentAvg,
            sleepDebt,
            hasDebtData: last7Days.length > 0,
            optimalBedtime,
            maxAvgScore,
            bedtimeData,
            dayOfWeekData
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

    const MetricConfig = METRICS[selectedMetric];
    const MetricIcon = MetricConfig.icon;

    const handleExport = () => {
        const dataStr = JSON.stringify(dailyLog, null, 2);
        const blob = new Blob([dataStr], { type: "application/json" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = `sleep_tracker_backup_${new Date().toISOString().split('T')[0]}.json`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    };

    const formatDuration = (hours) => {
        if (!hours) return '0h 0m';
        const h = Math.floor(hours);
        const m = Math.round((hours - h) * 60);
        return `${h}h ${m}m`;
    };

    return (
        <div className="space-y-8 pb-24">
            <div className="flex items-center justify-between">
                <div className="space-y-2">
                    <h2 className="text-2xl font-bold text-white">Insights</h2>
                    <p className="text-zinc-400">What drives your {MetricConfig.label}?</p>
                </div>
                <button
                    onClick={handleExport}
                    className="p-2 bg-zinc-900/50 hover:bg-zinc-800 text-zinc-400 hover:text-white rounded-xl border border-zinc-800 transition-all"
                    title="Export Data"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                        <polyline points="7 10 12 15 17 10" />
                        <line x1="12" y1="15" x2="12" y2="3" />
                    </svg>
                </button>
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

            {/* Key Stats */}
            <div className="grid grid-cols-2 gap-4">
                <div className="p-5 rounded-2xl bg-zinc-900/50 border border-zinc-800">
                    <div className="text-zinc-400 text-xs font-medium uppercase tracking-wider mb-1">7-Day Avg</div>
                    <div className="flex items-baseline gap-1">
                        <div className="text-3xl font-bold text-white">
                            {selectedMetric === 'duration' || selectedMetric === 'deepSleep'
                                ? formatDuration(stats.recentAvg)
                                : Math.round(stats.recentAvg)}
                        </div>
                        {selectedMetric !== 'duration' && selectedMetric !== 'deepSleep' && (
                            <span className="text-sm text-zinc-500 font-medium">{MetricConfig.unit}</span>
                        )}
                    </div>
                </div>

                {/* Sleep Debt Card */}
                <div className="p-5 rounded-2xl bg-zinc-900/50 border border-zinc-800">
                    <div className="text-zinc-400 text-xs font-medium uppercase tracking-wider mb-1">Sleep Debt (7d)</div>
                    {stats.hasDebtData ? (
                        <div className="flex items-baseline gap-1">
                            <div className={cn(
                                "text-3xl font-bold",
                                stats.sleepDebt > 0 ? "text-rose-400" : "text-emerald-400"
                            )}>
                                {stats.sleepDebt > 0 ? '-' : '+'}{Math.abs(stats.sleepDebt).toFixed(1)}
                            </div>
                            <span className="text-sm text-zinc-500 font-medium">hr</span>
                        </div>
                    ) : (
                        <div className="text-zinc-500 italic text-sm mt-1">Not enough data</div>
                    )}
                </div>

                {/* Optimal Bedtime Card */}
                <div className="col-span-2 p-5 rounded-2xl bg-gradient-to-br from-indigo-900/20 to-purple-900/20 border border-indigo-500/20">
                    <div className="text-indigo-300 text-xs font-medium uppercase tracking-wider mb-1">Optimal Bedtime</div>
                    {stats.optimalBedtime ? (
                        <div>
                            <div className="text-2xl font-bold text-white">{stats.optimalBedtime}</div>
                            <div className="text-sm text-zinc-400 mt-1">
                                Avg Sleep Score: <span className="text-indigo-400 font-bold">{Math.round(stats.maxAvgScore)}</span>
                            </div>
                        </div>
                    ) : (
                        <div className="text-zinc-500 italic text-sm mt-1">Log more bedtimes to see insights</div>
                    )}
                </div>
            </div>

            {/* Impact Scorecard */}
            <div className="space-y-4">
                <h3 className="text-lg font-bold text-white">Habit Impact</h3>
                <div className="grid gap-3">
                    {stats.habitImpacts.map((habit) => {
                        // Determine if impact is "good" or "bad"
                        // For RHR (inverse): Negative impact is GOOD (Green), Positive is BAD (Red)
                        // For others: Positive impact is GOOD (Green), Negative is BAD (Red)

                        let isGood = habit.impact > 0;
                        if (MetricConfig.inverse) isGood = !isGood;

                        // Neutral if no impact or not significant
                        const isNeutral = !habit.isSignificant || Math.abs(habit.impact) < 0.1;

                        const colorClass = isNeutral
                            ? "text-zinc-400 bg-zinc-800/50 border-zinc-800"
                            : isGood
                                ? "text-emerald-400 bg-emerald-950/30 border-emerald-900/50"
                                : "text-rose-400 bg-rose-950/30 border-rose-900/50";

                        const valueColor = isNeutral
                            ? "text-zinc-500"
                            : isGood
                                ? "text-emerald-400"
                                : "text-rose-400";

                        return (
                            <div key={habit.id} className={cn("flex items-center justify-between p-4 rounded-2xl border", colorClass)}>
                                <div>
                                    <div className="font-bold text-zinc-200">
                                        {habit.label} <span className="text-xs text-zinc-500 font-normal">{habit.labelDetail}</span>
                                    </div>
                                    <div className="text-xs text-zinc-500 mt-0.5">
                                        {habit.labelDetail ? (
                                            <span>Based on {habit.countWith} entries</span>
                                        ) : (
                                            <span>{habit.countWith} days with {habit.avgValue ? `(avg ${habit.avgValue.toFixed(1)})` : ''} • {habit.countWithout} days without</span>
                                        )}
                                    </div>
                                </div>
                                <div className="text-right">
                                    {habit.isSignificant ? (
                                        <>
                                            <div className={cn("text-xl font-bold", valueColor)}>
                                                {habit.impact > 0 ? '+' : ''}{habit.impact.toFixed(1)}
                                                <span className="text-sm font-medium ml-0.5">{MetricConfig.unit}</span>
                                            </div>
                                            <div className="text-xs text-zinc-500 font-medium">Impact</div>
                                        </>
                                    ) : (
                                        <div className="text-xs text-zinc-500 italic">Not enough data</div>
                                    )}
                                </div>
                            </div>
                        );
                    })}
                    {stats.habitImpacts.length === 0 && (
                        <div className="p-8 text-center border border-dashed border-zinc-800 rounded-2xl">
                            <p className="text-zinc-500">No habits tracked yet.</p>
                        </div>
                    )}
                </div>
            </div>

            {/* Trend Chart */}
            <div className="p-6 rounded-3xl bg-zinc-900/50 border border-zinc-800">
                <h3 className="text-lg font-bold text-white mb-6">{MetricConfig.label} Trend</h3>
                <div className="h-64 w-full">
                    <ResponsiveContainer width="100%" height="100%">
                        <LineChart data={stats.entries}>
                            <defs>
                                <linearGradient id="lineGradient" x1="0" y1="0" x2="1" y2="0">
                                    <stop offset="0%" stopColor={MetricConfig.color} />
                                    <stop offset="100%" stopColor={MetricConfig.color} stopOpacity={0.5} />
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
                                domain={['auto', 'auto']}
                            />
                            <Tooltip
                                contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '12px' }}
                                itemStyle={{ color: '#fff' }}
                                labelStyle={{ color: '#a1a1aa', marginBottom: '4px' }}
                                formatter={(value) => [
                                    selectedMetric === 'duration' || selectedMetric === 'deepSleep'
                                        ? formatDuration(value)
                                        : `${value} ${MetricConfig.unit}`,
                                    MetricConfig.label
                                ]}
                            />
                            <Line
                                type="monotone"
                                dataKey={selectedMetric}
                                stroke={MetricConfig.color}
                                strokeWidth={3}
                                dot={{ fill: '#18181b', stroke: MetricConfig.color, strokeWidth: 2, r: 4 }}
                                activeDot={{ r: 6, fill: '#fff' }}
                            />
                        </LineChart>
                    </ResponsiveContainer>
                </div>
            </div>

            {/* Bedtime & Day of Week Analysis Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Bedtime Impact Chart */}
                <div className="p-6 rounded-3xl bg-zinc-900/50 border border-zinc-800">
                    <h3 className="text-lg font-bold text-white mb-2">Bedtime Impact</h3>
                    <p className="text-sm text-zinc-400 mb-6">How average {MetricConfig.label.toLowerCase()} changes by bedtime hour</p>
                    <div className="h-48 w-full">
                        <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={stats.bedtimeData}>
                                <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                                <XAxis
                                    dataKey="label"
                                    stroke="#52525b"
                                    tick={{ fontSize: 12 }}
                                    tickLine={false}
                                    axisLine={false}
                                    dy={10}
                                />
                                <YAxis hide />
                                <Tooltip
                                    cursor={{ fill: '#27272a' }}
                                    contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '12px' }}
                                    itemStyle={{ color: '#fff' }}
                                    labelStyle={{ color: '#a1a1aa', marginBottom: '4px' }}
                                    formatter={(value) => [
                                        selectedMetric === 'duration' || selectedMetric === 'deepSleep'
                                            ? formatDuration(value)
                                            : `${value} ${MetricConfig.unit}`,
                                        'Average'
                                    ]}
                                />
                                <Bar dataKey="value" radius={[4, 4, 0, 0]}>
                                    {stats.bedtimeData.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={MetricConfig.color} fillOpacity={0.8} />
                                    ))}
                                </Bar>
                            </BarChart>
                        </ResponsiveContainer>
                    </div>
                </div>

                {/* Day of Week Analysis Chart */}
                <div className="p-6 rounded-3xl bg-zinc-900/50 border border-zinc-800">
                    <h3 className="text-lg font-bold text-white mb-2">Day of Week</h3>
                    <p className="text-sm text-zinc-400 mb-6">Average {MetricConfig.label.toLowerCase()} by day</p>
                    <div className="h-48 w-full">
                        <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={stats.dayOfWeekData}>
                                <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                                <XAxis
                                    dataKey="label"
                                    stroke="#52525b"
                                    tick={{ fontSize: 12 }}
                                    tickLine={false}
                                    axisLine={false}
                                    dy={10}
                                />
                                <YAxis hide />
                                <Tooltip
                                    cursor={{ fill: '#27272a' }}
                                    contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '12px' }}
                                    itemStyle={{ color: '#fff' }}
                                    labelStyle={{ color: '#a1a1aa', marginBottom: '4px' }}
                                    formatter={(value) => [
                                        selectedMetric === 'duration' || selectedMetric === 'deepSleep'
                                            ? formatDuration(value)
                                            : `${value} ${MetricConfig.unit}`,
                                        'Average'
                                    ]}
                                />
                                <Bar dataKey="value" radius={[4, 4, 0, 0]}>
                                    {stats.dayOfWeekData.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={MetricConfig.color} fillOpacity={0.8} />
                                    ))}
                                </Bar>
                            </BarChart>
                        </ResponsiveContainer>
                    </div>
                </div>
            </div>
        </div>
    );
}
