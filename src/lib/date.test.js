import { describe, expect, it } from 'vitest';
import { formatLocalDate, getRelativeLocalDate, parseLocalDate } from './date';

describe('date helpers', () => {
    it('formats relative dates using local calendar days instead of UTC strings', () => {
        const justAfterMidnight = new Date(2026, 2, 12, 0, 30);

        expect(getRelativeLocalDate(justAfterMidnight, -1)).toBe('2026-03-11');
    });

    it('round-trips yyyy-mm-dd dates without changing the calendar day', () => {
        expect(formatLocalDate(parseLocalDate('2026-03-11'))).toBe('2026-03-11');
    });
});
