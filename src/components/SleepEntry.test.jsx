import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { SleepEntry } from './SleepEntry';

describe('SleepEntry', () => {
    afterEach(() => {
        vi.useRealTimers();
        cleanup();
    });

    it('calls onSave after saving an entry', () => {
        vi.useFakeTimers();

        const onSave = vi.fn();
        const setDailyLog = vi.fn();

        render(
            <SleepEntry
                dailyLog={{}}
                setDailyLog={setDailyLog}
                onSave={onSave}
                selectedDate="2026-03-11"
            />
        );

        fireEvent.change(screen.getByPlaceholderText('85'), {
            target: { value: '86' }
        });
        fireEvent.click(screen.getByRole('button', { name: /save entry/i }));

        expect(setDailyLog).toHaveBeenCalledTimes(1);

        vi.runAllTimers();

        expect(onSave).toHaveBeenCalledTimes(1);
    });

    it('loads the selected date entry and auto-calculates duration across midnight', () => {
        const { container, rerender } = render(
            <SleepEntry
                dailyLog={{
                    '2026-03-10': {
                        sleepScore: 74,
                        bedtime: '23:40',
                        waketime: '07:10',
                        durationHours: 7,
                        durationMinutes: 30,
                        deepHours: 1,
                        deepMinutes: 15,
                        bodyBattery: 44,
                        hrv: 61,
                        rhr: 53,
                        notes: 'Initial entry'
                    }
                }}
                setDailyLog={vi.fn()}
                onSave={vi.fn()}
                selectedDate="2026-03-10"
            />
        );

        const scoreInput = screen.getByPlaceholderText('85');
        expect(scoreInput.value).toBe('74');

        rerender(
            <SleepEntry
                dailyLog={{
                    '2026-03-11': {
                        sleepScore: 88,
                        bedtime: '23:30',
                        waketime: '07:15',
                        durationHours: 7,
                        durationMinutes: 45,
                        deepHours: 1,
                        deepMinutes: 50,
                        bodyBattery: 68,
                        hrv: 84,
                        rhr: 49,
                        notes: 'Better sleep'
                    }
                }}
                setDailyLog={vi.fn()}
                onSave={vi.fn()}
                selectedDate="2026-03-11"
            />
        );

        expect(scoreInput.value).toBe('88');

        const timeInputs = container.querySelectorAll('input[type="time"]');
        fireEvent.change(timeInputs[0], { target: { value: '23:30' } });
        fireEvent.change(timeInputs[1], { target: { value: '07:15' } });

        const durationInputs = Array.from(
            container.querySelectorAll('input[type="number"]')
        );

        expect(durationInputs[1].value).toBe('7');
        expect(durationInputs[2].value).toBe('45');
    });
});
