import React, { useState } from 'react';
import { Layout } from './components/Layout';
import { HabitTracker } from './components/HabitTracker';
import { SleepEntry } from './components/SleepEntry';
import { Dashboard } from './components/Dashboard';
import { useLocalStorage } from './hooks/useLocalStorage';

const DEFAULT_HABITS = [
  { id: 'caffeine', label: 'No caffeine after 2 PM' },
  { id: 'screens', label: 'No screens 1h before bed' },
  { id: 'read', label: 'Read a book' },
  { id: 'magnesium', label: 'Took Magnesium' },
  { id: 'meditation', label: 'Meditation (10m)' },
  { id: 'hot_shower', label: 'Hot shower/bath' },
];

function App() {
  const [activeTab, setActiveTab] = useState('habits');
  const [habits, setHabits] = useLocalStorage('sleep_tracker_habits', DEFAULT_HABITS);
  const [dailyLog, setDailyLog] = useLocalStorage('sleep_tracker_logs', {});

  return (
    <Layout activeTab={activeTab} setActiveTab={setActiveTab}>
      {activeTab === 'habits' && (
        <HabitTracker
          habits={habits}
          setHabits={setHabits}
          dailyLog={dailyLog}
          setDailyLog={setDailyLog}
        />
      )}

      {activeTab === 'log' && (
        <SleepEntry
          dailyLog={dailyLog}
          setDailyLog={setDailyLog}
          setActiveTab={setActiveTab}
        />
      )}

      {activeTab === 'dashboard' && (
        <Dashboard
          dailyLog={dailyLog}
          habits={habits}
        />
      )}
    </Layout>
  );
}

export default App;
