import 'package:mayabela/models/finance_models.dart';
import 'package:mayabela/services/finance_service.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class FinancePersistenceService {
  FinancePersistenceService._();
  static final instance = FinancePersistenceService._();

  static const _structuresKey = 'finance_structures_v1';
  static const _invoicesKey = 'finance_invoices_v1';
  static const _paymentsKey = 'finance_payments_v1';
  static const _cashboxesKey = 'finance_cashboxes_v1';
  static const _cashMovesKey = 'finance_cash_moves_v1';
  static const _cashClosesKey = 'finance_cash_closes_v1';
  static const _expensesKey = 'finance_expenses_v1';
  static const _budgetsKey = 'finance_budgets_v1';
  static const _disbursementsKey = 'finance_disbursements_v1';
  static const _payablesKey = 'finance_payables_v1';
  static const _auditKey = 'finance_audit_v1';

  Future<void> loadIntoService() async {
    Future<List<T>> read<T>(
      String key,
      T Function(Map<String, dynamic>) parse,
    ) async {
      final items = <T>[];
      for (final map in await LocalJsonStore.readList(key)) {
        try {
          items.add(parse(map));
        } catch (_) {}
      }
      return items;
    }

    FinanceService.instance.applyPersistedData(
      structures: await read(_structuresKey, FinanceFeeStructure.fromMap),
      invoices: await read(_invoicesKey, FinanceInvoice.fromMap),
      payments: await read(_paymentsKey, FinancePayment.fromMap),
      cashboxes: await read(_cashboxesKey, FinanceCashbox.fromMap),
      cashMoves: await read(_cashMovesKey, FinanceCashMovement.fromMap),
      cashCloses: await read(_cashClosesKey, FinanceCashClose.fromMap),
      expenses: await read(_expensesKey, FinanceExpense.fromMap),
      budgets: await read(_budgetsKey, FinanceBudget.fromMap),
      disbursements:
          await read(_disbursementsKey, FinanceBudgetDisbursement.fromMap),
      payables: await read(_payablesKey, FinancePayable.fromMap),
      audit: await read(_auditKey, FinanceAuditEvent.fromMap),
    );
  }

  Future<void> saveFromService({bool pushCloud = false}) async {
    final svc = FinanceService.instance;
    await LocalJsonStore.writeList(
      _structuresKey,
      svc.structures.map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _invoicesKey,
      svc.invoices.map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _paymentsKey,
      svc.payments.map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _cashboxesKey,
      svc.cashboxes.map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _cashMovesKey,
      svc.cashMoves.map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _cashClosesKey,
      svc.cashCloses.map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _expensesKey,
      svc.expenses.map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _budgetsKey,
      svc.budgets.map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _disbursementsKey,
      svc.disbursements.map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _payablesKey,
      svc.payables.map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _auditKey,
      svc.audit.map((e) => e.toMap()).toList(),
    );
  }
}
