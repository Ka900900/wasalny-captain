import 'package:flutter/material.dart';

/// Represents a single transaction (earning, withdrawal, or payment).
class WalletTransaction {
  final String id;
  final String type; // 'earning' | 'withdraw' | 'payment'
  final double amount;
  final String description;
  final String status; // 'completed' | 'pending' | 'failed'
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory WalletTransaction.fromMap(String id, Map<String, dynamic> map) {
    return WalletTransaction(
      id: id,
      type: map['type'] as String? ?? 'earning',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'completed',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'amount': amount,
        'description': description,
        'status': status,
        'createdAt': createdAt,
      };

  /// Whether this transaction added money to the wallet.
  bool get isCredit => type == 'earning' || (type == 'withdraw' && status == 'rejected');

  /// Whether this transaction removed money from the wallet.
  bool get isDebit => (type == 'withdraw' && status == 'completed') || type == 'payment';
}

/// A withdrawal request submitted by the captain.
class WithdrawRequest {
  final String id;
  final double amount;
  final String status; // 'pending' | 'approved' | 'completed' | 'rejected'
  final String? bankAccount;
  final String? bankName;
  final String? accountHolder;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const WithdrawRequest({
    required this.id,
    required this.amount,
    required this.status,
    this.bankAccount,
    this.bankName,
    this.accountHolder,
    required this.createdAt,
    this.updatedAt,
  });

  factory WithdrawRequest.fromMap(String id, Map<String, dynamic> map) {
    return WithdrawRequest(
      id: id,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'pending',
      bankAccount: map['bankAccount'] as String?,
      bankName: map['bankName'] as String?,
      accountHolder: map['accountHolder'] as String?,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'status': status,
        'bankAccount': bankAccount,
        'bankName': bankName,
        'accountHolder': accountHolder,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'approved':
        return 'تمت الموافقة';
      case 'completed':
        return 'مكتمل';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }

  String get statusIcon {
    switch (status) {
      case 'pending':
        return '⏳';
      case 'approved':
        return '✅';
      case 'completed':
        return '💰';
      case 'rejected':
        return '❌';
      default:
        return '❓';
    }
  }
}

/// Aggregated wallet data for the current driver.
class WalletData {
  final double balance;
  final double pendingWithdraw;
  final double totalEarned;
  final double totalWithdrawn;
  final List<WalletTransaction> recentTransactions;

  const WalletData({
    this.balance = 0,
    this.pendingWithdraw = 0,
    this.totalEarned = 0,
    this.totalWithdrawn = 0,
    this.recentTransactions = const [],
  });

  factory WalletData.fromMap(Map<String, dynamic> map) {
    return WalletData(
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      pendingWithdraw: (map['pendingWithdraw'] as num?)?.toDouble() ?? 0,
      totalEarned: (map['totalEarned'] as num?)?.toDouble() ?? 0,
      totalWithdrawn: (map['totalWithdrawn'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'balance': balance,
        'pendingWithdraw': pendingWithdraw,
        'totalEarned': totalEarned,
        'totalWithdrawn': totalWithdrawn,
      };
}

/// A saved payment method.
class PaymentMethod {
  final String id;
  final String type; // 'bank' | 'vodafone_cash' | 'instapay'
  final String label;
  final String? accountNumber;
  final String? bankName;
  final bool isDefault;

  const PaymentMethod({
    required this.id,
    required this.type,
    required this.label,
    this.accountNumber,
    this.bankName,
    this.isDefault = false,
  });

  factory PaymentMethod.fromMap(String id, Map<String, dynamic> map) {
    return PaymentMethod(
      id: id,
      type: map['type'] as String? ?? 'bank',
      label: map['label'] as String? ?? '',
      accountNumber: map['accountNumber'] as String?,
      bankName: map['bankName'] as String?,
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }

  IconData get icon {
    switch (type) {
      case 'bank':
        return Icons.account_balance;
      case 'vodafone_cash':
        return Icons.phone_android;
      case 'instapay':
        return Icons.send;
      default:
        return Icons.payment;
    }
  }
}
