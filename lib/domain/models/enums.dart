// lib/domain/models/enums.dart
// Enums usados em services/UI

enum OrderStatus {
  open,       // pedido aberto
  billed,     // faturado
  canceled,   // cancelado
}

enum FinancialType {
  receivable, // a receber
  payable,    // a pagar
}

enum FinancialStatus {
  open,
  settled,
  canceled,
}
