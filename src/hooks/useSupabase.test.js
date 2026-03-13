import { describe, expect, it } from 'vitest';
import { resolveUpdatedDailyLog } from './useSupabase';

describe('resolveUpdatedDailyLog', () => {
    it('resolves functional updates before syncing', () => {
        const currentLog = {
            '2026-03-12': {
                sleepScore: 81,
                habits: ['read']
            }
        };

        const nextLog = resolveUpdatedDailyLog(currentLog, (previous) => ({
            ...previous,
            '2026-03-13': {
                sleepScore: 86,
                habits: ['banana']
            }
        }));

        expect(nextLog).toEqual({
            '2026-03-12': {
                sleepScore: 81,
                habits: ['read']
            },
            '2026-03-13': {
                sleepScore: 86,
                habits: ['banana']
            }
        });
    });
});
