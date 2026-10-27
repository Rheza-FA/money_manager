import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/models/expense.dart';
import 'package:money_manager/providers/calculator_provider.dart';

void main() {
  Expense tx({
    required String name,
    required double amount,
    required DateTime date,
    DateTime? recordedAt,
    bool isIncome = false,
  }) {
    return Expense()
      ..name = name
      ..quantity = 1
      ..price = amount
      ..totalAmount = amount
      ..date = date
      ..recordedAt = recordedAt
      ..isIncome = isIncome;
  }

  group('BudgetMath.dailyLimit (locked daily allowance + rollover)', () {
    test(
      'never shrinks mid-day when adding manual expenses or backdated shared receipts today',
      () {
        // October has 31 days. On Oct 10 (14:00), 22 days remain in the month (Oct 10..31).
        final DateTime today = DateTime(2026, 10, 10, 14, 0);
        const double openingBalance = 2200000;

        // Baseline: 0 transactions -> 2,200,000 / 22 = 100,000/day
        final double baseline = BudgetMath.dailyLimit(
          records: const <Expense>[],
          openingBalance: openingBalance,
          isBiWeekly: false,
          now: today,
        );
        expect(baseline, 100000);

        // 1. User adds a manual expense dated today AND imports a backdated
        //    shared receipt from Oct 5 (recordedAt = today).
        final List<Expense> afterTodayActivity = <Expense>[
          tx(
            name: 'Lunch',
            amount: 45000,
            date: DateTime(2026, 10, 10, 12, 30),
            recordedAt: DateTime(2026, 10, 10, 12, 30),
          ),
          tx(
            name: 'BRImo QRIS Backdated Receipt',
            amount: 120000,
            date: DateTime(2026, 10, 5, 19, 10),
            recordedAt: DateTime(2026, 10, 10, 13, 55),
          ),
          tx(
            name: 'Shared Incoming Transfer',
            amount: 300000,
            date: DateTime(2026, 10, 10, 13, 58),
            recordedAt: DateTime(2026, 10, 10, 13, 58),
            isIncome: true,
          ),
        ];

        final double stillLockedToday = BudgetMath.dailyLimit(
          records: afterTodayActivity,
          openingBalance: openingBalance,
          isBiWeekly: false,
          now: today,
        );
        expect(stillLockedToday, baseline);
      },
    );

    test(
      'rolls unspent allowance forward to increase tomorrow limit, and reduces tomorrow limit when over-spent',
      () {
        // Oct 10: 22 days left, opening = 2,200,000 -> today's limit = 100,000.
        // Case A: User only spends 40,000 on Oct 10 (60,000 under limit).
        final List<Expense> underSpent = <Expense>[
          tx(
            name: 'Coffee & Pastry',
            amount: 40000,
            date: DateTime(2026, 10, 10, 9, 0),
            recordedAt: DateTime(2026, 10, 10, 9, 0),
          ),
        ];

        // On Oct 11 (21 days left): (2,200,000 - 40,000) / 21 = 2,160,000 / 21 > 100,000!
        final double nextDayAfterSaving = BudgetMath.dailyLimit(
          records: underSpent,
          openingBalance: 2200000,
          isBiWeekly: false,
          now: DateTime(2026, 10, 11, 8, 0),
        );
        expect(nextDayAfterSaving, closeTo(2160000 / 21, 0.01));
        expect(nextDayAfterSaving, greaterThan(100000));

        // Case B: User spends 310,000 on Oct 10 (210,000 over limit).
        final List<Expense> overSpent = <Expense>[
          tx(
            name: 'Groceries',
            amount: 310000,
            date: DateTime(2026, 10, 10, 18, 0),
            recordedAt: DateTime(2026, 10, 10, 18, 0),
          ),
        ];

        // On Oct 11 (21 days left): (2,200,000 - 310,000) / 21 = 1,890,000 / 21 = 90,000 (< 100,000).
        final double nextDayAfterOverspend = BudgetMath.dailyLimit(
          records: overSpent,
          openingBalance: 2200000,
          isBiWeekly: false,
          now: DateTime(2026, 10, 11, 8, 0),
        );
        expect(nextDayAfterOverspend, 90000);
      },
    );

    test(
      'settled incoming money increases subsequent daily limit and Cycle 2 reflects Cycle 1 cashflow',
      () {
        final List<Expense> records = <Expense>[
          tx(
            name: 'Cycle 1 Spending',
            amount: 500000,
            date: DateTime(2026, 10, 5, 12, 0),
            recordedAt: DateTime(2026, 10, 5, 12, 0),
          ),
          tx(
            name: 'Freelance Incoming',
            amount: 200000,
            date: DateTime(2026, 10, 12, 15, 0),
            recordedAt: DateTime(2026, 10, 12, 15, 0),
            isIncome: true,
          ),
        ];

        // On Oct 15 (start of bi-weekly Cycle 2, 17 days remaining Oct 15..31):
        // Available = 2,000,000 - 500,000 + 200,000 = 1,700,000 -> 1,700,000 / 17 = 100,000.
        final double cycle2Limit = BudgetMath.dailyLimit(
          records: records,
          openingBalance: 2000000,
          isBiWeekly: true,
          now: DateTime(2026, 10, 15, 9, 0),
        );
        expect(cycle2Limit, 100000);
      },
    );
  });

  group('BudgetMath.liveBalance & spentOn', () {
    test('decreases immediately on expenses and increases immediately on income', () {
      final DateTime now = DateTime(2026, 10, 26, 15, 0);
      final List<Expense> records = <Expense>[
        tx(
          name: 'Kopi Kenangan',
          amount: 32000,
          date: DateTime(2026, 10, 26, 10, 0),
        ),
        tx(
          name: 'Andi Wijaya',
          amount: 150000,
          date: DateTime(2026, 10, 26, 14, 0),
          isIncome: true,
        ),
        // Previous month record must not affect October's monthly balance
        tx(
          name: 'Old Sept Expense',
          amount: 999000,
          date: DateTime(2026, 9, 28, 12, 0),
        ),
      ];

      expect(
        BudgetMath.liveBalance(
          records: records,
          openingBalance: 1000000,
          now: now,
        ),
        1000000 - 32000 + 150000,
      );

      // spentOn must exclude incoming transfers
      expect(BudgetMath.spentOn(records, now), 32000);
    });
  });
}
