import React from 'react';
import { Layout } from './components/Layout';
import { HabitTracker } from './components/HabitTracker';
import { SleepEntry } from './components/SleepEntry';
import { Dashboard } from './components/Dashboard';
import { useSupabase } from './hooks/useSupabase';

export default function App() {
  const { dailyLog, setDailyLog, habits, setHabits, loading, error } = useSupabase();
  const [currentPage, setCurrentPage] = React.useState('dashboard');

  if (loading) {
    return (
      <div className="min-h-screen bg-zinc-950 flex items-center justify-center text-zinc-500">
        Loading...
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-zinc-950 flex items-center justify-center text-red-500">
        Error: {error}
      </div>
    );
  }

  return (
    <Layout currentPage={currentPage} setCurrentPage={setCurrentPage}>
      {currentPage === 'habits' && (
        <HabitTracker
          habits={habits}
          setHabits={setHabits}
          dailyLog={dailyLog}
          setDailyLog={setDailyLog}
        />
      )}
      {currentPage === 'log' && (
        <SleepEntry
          dailyLog={dailyLog}
          setDailyLog={setDailyLog}
          onSave={() => setCurrentPage('dashboard')}
        />
      )}
      {currentPage === 'dashboard' && (
        <Dashboard
          dailyLog={dailyLog}
          habits={habits}
        />
      )}
    </Layout>
  );
}
