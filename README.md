# Chembikkal Food Court (CFC) System

This repository contains two distinct Flutter applications sharing a unified Supabase cloud database:

---

## 1. Restaurant Staff & POS App
The comprehensive Point of Sale system for counter staff, waiters, cashiers, and managers.

- **Features**: Dine-in table management, Walkin/Parcel ordering, Multi-shop cart, Split billing, Void/Refund management, Cashier reconciliation.
- **Entry point**: `lib/main.dart`
- **Run locally**:
  ```bash
  flutter run -t lib/main.dart
  ```
- **Build APK for Counter Devices**:
  ```bash
  flutter build apk -t lib/main.dart
  ```

---

## 2. Dedicated Delivery Partner App
The lightweight, mobile-first standalone app designed exclusively for delivery staff personal phones.

- **Features**:
  - **Zero POS Access**: Delivery drivers cannot see POS terminals, tables, or cashier reports.
  - **Realtime Order Sync**: New delivery orders placed by POS staff pop up automatically.
  - **Customer Quick Actions**: One-tap Phone Call, WhatsApp chat, and Google Maps turn-by-turn navigation.
  - **Prepaid vs Unpaid Detection**:
    - 🟢 *Prepaid at Counter/Call*: Marked `COLLECT ₹0` with handover confirmation.
    - 🔴 *Payment Pending at Door*: Collect Cash, GPay, or Split at customer's doorstep with green tally verification.
  - **Shift Collections Summary**: Displays deliveries completed today, total cash in hand to return to counter, and GPay collected.
- **Entry point**: `lib/main_delivery.dart`
- **Run locally**:
  ```bash
  flutter run -t lib/main_delivery.dart
  ```
- **Build APK for Delivery Staff Phones**:
  ```bash
  flutter build apk -t lib/main_delivery.dart
  ```
