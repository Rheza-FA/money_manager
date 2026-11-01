import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/features/receipt_share/models/shared_receipt.dart';
import 'package:money_manager/features/receipt_share/parser/receipt_parser.dart';

void main() {
  final DateTime refNow = DateTime(2026, 10, 25, 18, 0);

  group('ReceiptParser.parseRupiahNumber', () {
    test('normalizes Indonesian, English, and OCR-quirk currency numbers', () {
      expect(ReceiptParser.parseRupiahNumber('28.500'), 28500);
      expect(ReceiptParser.parseRupiahNumber('150.000,00'), 150000);
      expect(ReceiptParser.parseRupiahNumber('1.250.000,00'), 1250000);
      expect(ReceiptParser.parseRupiahNumber('1,250,000.00'), 1250000);
      expect(ReceiptParser.parseRupiahNumber('28,500'), 28500);
      expect(ReceiptParser.parseRupiahNumber('50000,00'), 50000);
      expect(ReceiptParser.parseRupiahNumber('50000'), 50000);
      expect(
        ReceiptParser.parseRupiahNumber('50.00O', allowOcrZeroFix: true),
        50000,
      );
    });
  });

  group('ReceiptParser real-world Indonesian receipts', () {
    test('parses GoPay QRIS receipt and ignores GoPay Coins & Ref IDs', () {
      const SharedReceiptPayload payload = SharedReceiptPayload(
        referrer: 'com.gojek.app',
        ocrLines: <String>[
          'gopay',
          'Pembayaran berhasil',
          'Rp28.500',
          'Kopi Kenangan, Tebet',
          '25 Okt 2026, 17:15 WIB',
          'Rincian transaksi',
          'Metode pembayaran   GoPay Saldo',
          'GoPay Coins   -Rp3.500',
          'Total pembayaran   Rp28.500',
          'ID Transaksi   GP-991827364512',
          'NMID   ID102003004005',
        ],
      );

      final ParsedReceipt result = ReceiptParser.parse(payload, now: refNow);
      expect(result.sourceLabel, 'GoPay • QRIS');
      expect(result.isQris, isTrue);
      expect(result.itemName, 'Kopi Kenangan, Tebet');
      expect(result.amount, 28500);
      expect(result.date, DateTime(2026, 10, 25, 17, 15));
      expect(result.hasExplicitDate, isTrue);
      expect(result.isLikelyIncoming, isFalse);
      expect(result.isComplete, isTrue);
    });

    test('parses myBCA stacked QRIS receipt with IDR format', () {
      const SharedReceiptPayload payload = SharedReceiptPayload(
        ocrLines: <String>[
          'myBCA',
          'Transaksi Berhasil',
          '25 Okt 2026 14:08:22 WIB',
          'Pembayaran QRIS',
          'Nama Merchant',
          'KOPI KENANGAN - GRAND INDONESIA, ID',
          'Lokasi Merchant',
          'JAKARTA PUSAT',
          'Nominal Transaksi',
          'IDR 45.000,00',
          'Biaya Admin',
          'IDR 0,00',
          'Total Nominal',
          'IDR 45.000,00',
          'No. Referensi',
          '429814082200',
        ],
      );

      final ParsedReceipt result = ReceiptParser.parse(payload, now: refNow);
      expect(result.sourceLabel, 'BCA • QRIS');
      expect(result.itemName, 'Kopi Kenangan - Grand Indonesia');
      expect(result.amount, 45000);
      expect(result.date, DateTime(2026, 10, 25, 14, 8, 22));
    });

    test('parses classic m-BCA transfer with short date, account skip, and Berita', () {
      const SharedReceiptPayload payload = SharedReceiptPayload(
        ocrLines: <String>[
          'm-Transfer :',
          'BERHASIL',
          '25/10 12:30:15',
          'Ke 5271234567',
          'BUDI SANTOSO',
          'Rp. 150.000,00',
          'Berita : Makan siang kantor',
          'Ref : 0251230159988',
        ],
      );

      final ParsedReceipt result = ReceiptParser.parse(payload, now: refNow);
      expect(result.sourceLabel, 'BCA');
      expect(result.itemName, 'Makan siang kantor');
      expect(
        result.nameCandidates,
        containsAll(<String>['Makan siang kantor', 'Budi Santoso']),
      );
      expect(result.amount, 150000);
      expect(result.date, DateTime(2026, 10, 25, 12, 30, 15));
    });

    test('parses Livin Mandiri transfer to BCA without misidentifying sender bank', () {
      const SharedReceiptPayload payload = SharedReceiptPayload(
        ocrLines: <String>[
          "livin' by mandiri",
          'Transfer Berhasil!',
          '24 Okt 2026 - 19.42 WIB',
          'Penerima   PT GOTO GOJEK TOKOPEDIA',
          'Bank Tujuan   Bank BCA - 1234567890',
          'Nominal Transfer   Rp 50.000',
          'Biaya Transaksi   Rp 2.500',
          'Total Transaksi   Rp 52.500',
          'Catatan   -',
        ],
      );

      final ParsedReceipt result = ReceiptParser.parse(payload, now: refNow);
      expect(result.sourceLabel, "Livin' Mandiri");
      expect(result.itemName, 'PT Goto Gojek Tokopedia');
      expect(result.amount, 52500);
      expect(result.date, DateTime(2026, 10, 24, 19, 42));
    });

    test('reconciles Nominal + Biaya Admin when Total row is absent and ignores Sisa Saldo', () {
      const SharedReceiptPayload payload = SharedReceiptPayload(
        ocrLines: <String>[
          'BRImo',
          'Transaksi Berhasil',
          '25/10/2026 09:10:00',
          'Tujuan   WARUNG NASI BU SRI',
          'Nominal   Rp 35.000',
          'Biaya Admin   Rp 2.500',
          'Sisa Saldo   Rp 3.850.000',
        ],
      );

      final ParsedReceipt result = ReceiptParser.parse(payload, now: refNow);
      expect(result.sourceLabel, 'BRImo');
      expect(result.itemName, 'Warung Nasi Bu Sri');
      expect(result.amount, 37500);
    });

    test('parses DANA & ShopeePay negative-prefixed debit receipts and English locale', () {
      const SharedReceiptPayload danaPayload = SharedReceiptPayload(
        ocrLines: <String>[
          'DANA',
          'Pembayaran Berhasil!',
          '25 Okt 2026 · 16:05',
          'Bayar ke MIXUE ICE CREAM',
          'Total Bayar   Rp22.000',
          'Metode Pembayaran   Saldo DANA',
        ],
      );
      final ParsedReceipt dana = ReceiptParser.parse(danaPayload, now: refNow);
      expect(dana.sourceLabel, 'DANA');
      expect(dana.itemName, 'Mixue Ice Cream');
      expect(dana.amount, 22000);

      const SharedReceiptPayload shopeePayload = SharedReceiptPayload(
        ocrLines: <String>[
          'ShopeePay',
          'Berhasil',
          '-Rp19.500',
          'Pembayaran ke Alfamart Kebayoran',
          'Waktu Selesai   25-10-2026 08:20',
        ],
      );
      final ParsedReceipt shopee =
          ReceiptParser.parse(shopeePayload, now: refNow);
      expect(shopee.sourceLabel, 'ShopeePay');
      expect(shopee.itemName, 'Alfamart Kebayoran');
      expect(shopee.amount, 19500);
      expect(shopee.isLikelyIncoming, isFalse);

      const SharedReceiptPayload englishBank = SharedReceiptPayload(
        extraText: '''
Bank Jago
Successful Transaction
Oct 25, 2026 5:15 PM
Beneficiary: Fore Coffee Senopati
Total Amount: IDR 1,250,000.00
''',
      );
      final ParsedReceipt jago = ReceiptParser.parse(englishBank, now: refNow);
      expect(jago.sourceLabel, 'Bank Jago');
      expect(jago.itemName, 'Fore Coffee Senopati');
      expect(jago.amount, 1250000);
    });

    test('flags incoming credit receipts and extracts sender name as primary item', () {
      const SharedReceiptPayload incoming = SharedReceiptPayload(
        ocrLines: <String>[
          'SeaBank',
          'Transfer Masuk Berhasil',
          '+Rp 500.000',
          'Dari: Andi Wijaya',
          '25 Okt 2026 11:00',
        ],
      );

      final ParsedReceipt result = ReceiptParser.parse(incoming, now: refNow);
      expect(result.isLikelyIncoming, isTrue);
      expect(result.itemName, 'Andi Wijaya');
      expect(result.amount, 500000);
    });

    test(
      'strips GoPay Indonesian promotional share caption & static OneLink URL completely',
      () {
        const SharedReceiptPayload gopayWithPromo = SharedReceiptPayload(
          hasAttachment: true,
          referrer: 'com.gojek.gopay',
          extraText:
              'Hai, ini bukti transaksinya ya. Buat rincian lebih lanjut, bisa cek di app GoPay https://\napp.gopay.co.id/NF8p/x3fpwee1',
          ocrLines: <String>[
            '25 Okt 2026 · 19:04 WIB',
            'Pembayaran berhasil',
            '36.000', // Even when tiny superscript "Rp" is missed by OCR!
            'WARUNG PADANG SEDERHANA',
            'Metode pembayaran   GoPay Saldo',
            'ID Transaksi   GP-1122334455',
          ],
        );

        final ParsedReceipt parsed =
            ReceiptParser.parse(gopayWithPromo, now: refNow);
        expect(parsed.sourceLabel, 'GoPay');
        expect(parsed.itemName, 'Warung Padang Sederhana');
        expect(parsed.quantity, 1);
        expect(parsed.amount, 36000);
        expect(parsed.date, DateTime(2026, 10, 25, 19, 4));
        expect(
          parsed.rawPreviewLines.join('\n'),
          isNot(contains('bukti transaksinya ya')),
        );
        expect(
          parsed.rawPreviewLines.join('\n'),
          isNot(contains('gopay.co.id')),
        );
      },
    );

    test(
      'parses BRImo receipt while excluding Sumber Dana (sender name) from merchant candidates',
      () {
        const SharedReceiptPayload brimoPayload = SharedReceiptPayload(
          hasAttachment: true,
          referrer: 'id.co.bri.brimo',
          ocrLines: <String>[
            'Transaksi Berhasil',
            '25 Okt 2026, 19:06:14 WIB',
            'Nomor Referensi',
            '882910447123',
            'Sumber Dana',
            'RHEZA FIRMANSYAH',
            '0123 **** **** 567',
            'Jenis Transaksi',
            'Pembayaran QRIS',
            'Nama Merchant',
            'INDOMARET SUDIRMAN',
            'Nominal',
            'Rp 42.500',
            'Biaya Admin',
            'Rp 0',
            'Total Transaksi',
            'Rp 42.500',
          ],
        );

        final ParsedReceipt parsed =
            ReceiptParser.parse(brimoPayload, now: refNow);
        expect(parsed.sourceLabel, 'BRImo • QRIS');
        expect(parsed.itemName, 'Indomaret Sudirman');
        expect(parsed.nameCandidates, isNot(contains('Rheza Firmansyah')));
        expect(parsed.quantity, 1);
        expect(parsed.amount, 42500);
        expect(parsed.date, DateTime(2026, 10, 25, 19, 6, 14));
      },
    );

    test(
      'extracts Qty accurately from itemized multipliers and explicit Qty rows while preserving exact Rupiah total',
      () {
        // 1. Prefix multiplier `2x ...` with divisible total -> Qty = 2, Unit Price = 22.000
        const SharedReceiptPayload prefixQty = SharedReceiptPayload(
          referrer: 'com.gojek.app',
          ocrLines: <String>[
            'gopay',
            'Pembayaran berhasil',
            '25 Okt 2026, 15:20 WIB',
            '2x Kopi Kenangan Mantan',
            'Total pembayaran   Rp44.000',
          ],
        );
        final ParsedReceipt r1 = ReceiptParser.parse(prefixQty, now: refNow);
        expect(r1.itemName, 'Kopi Kenangan Mantan');
        expect(r1.quantity, 2);
        expect(r1.amount, 22000);
        expect(r1.quantity * r1.amount!, 44000);

        // 2. Explicit `Jumlah Barang` row -> Qty = 3, Unit Price = 15.000
        const SharedReceiptPayload explicitQty = SharedReceiptPayload(
          ocrLines: <String>[
            'Transaksi Berhasil',
            'Merchant   Toko Buku Gramedia',
            'Jumlah Barang   3 pcs',
            'Total Bayar   Rp 45.000',
          ],
        );
        final ParsedReceipt r2 = ReceiptParser.parse(explicitQty, now: refNow);
        expect(r2.itemName, 'Toko Buku Gramedia');
        expect(r2.quantity, 3);
        expect(r2.amount, 15000);
        expect(r2.quantity * r2.amount!, 45000);

        // 3. Inline `Name   2 x Rp 25.000` -> Qty = 2, Unit Price = 25.000
        const SharedReceiptPayload inlineTimes = SharedReceiptPayload(
          ocrLines: <String>[
            'Pembayaran Berhasil',
            'Nasi Goreng Spesial   2 x Rp 25.000   Rp 50.000',
            'Total   Rp 50.000',
          ],
        );
        final ParsedReceipt r3 = ReceiptParser.parse(inlineTimes, now: refNow);
        expect(r3.itemName, 'Nasi Goreng Spesial');
        expect(r3.quantity, 2);
        expect(r3.amount, 25000);

        // 4. Non-divisible total (3 items + Rp 2.000 fee = Rp 50.000) -> keeps Qty = 1 so total is exact
        const SharedReceiptPayload nonDivisible = SharedReceiptPayload(
          ocrLines: <String>[
            'Pembayaran Berhasil',
            '3x Roti Bakar',
            'Total Bayar   Rp 50.000',
          ],
        );
        final ParsedReceipt r4 = ReceiptParser.parse(nonDivisible, now: refNow);
        expect(r4.quantity, 1);
        expect(r4.amount, 50000);
      },
    );

    test(
      'handles 2-column BRImo Sumber Dana, bank-skip under Tujuan, and bare 2-column Total',
      () {
        const SharedReceiptPayload brimoTwoCol = SharedReceiptPayload(
          hasAttachment: true,
          referrer: 'id.co.bri.brimo',
          ocrLines: <String>[
            'Catatan Transaksi',
            'Transaksi Berhasil',
            '19:08 · 25 Okt 2026',
            'Sumber Dana   0123 **** **** 567',
            'RHEZA FIRMANSYAH',
            'Tujuan   BANK BCA',
            '5271234567',
            'TOKO MAJU JAYA',
            'Nominal   45.000',
            'Biaya Admin   0',
            'Total Transaksi   45.000',
          ],
        );

        final ParsedReceipt parsed =
            ReceiptParser.parse(brimoTwoCol, now: refNow);
        expect(parsed.sourceLabel, 'BRImo');
        expect(parsed.itemName, 'Toko Maju Jaya');
        expect(parsed.nameCandidates, isNot(contains('Rheza Firmansyah')));
        expect(parsed.nameCandidates, isNot(contains('Catatan Transaksi')));
        expect(parsed.amount, 45000);
        expect(parsed.quantity, 1);
        expect(parsed.date, DateTime(2026, 10, 25, 19, 8));
      },
    );

    test(
      'handles GoPay stacked Dibayar ke and extracts Qty multiplier inside Catatan',
      () {
        const SharedReceiptPayload gopayNoteQty = SharedReceiptPayload(
          hasAttachment: true,
          referrer: 'com.gojek.gopay',
          ocrLines: <String>[
            'Pembayaran berhasil',
            'Rp   36.000',
            'Dibayar ke',
            'WARUNG KOPI KITA',
            'Waktu   16:40',
            'Tanggal   25 Okt 2026',
            'Catatan   2x Kopi Susu Gula Aren',
            'Total pembayaran   Rp36.000',
          ],
        );

        final ParsedReceipt parsed =
            ReceiptParser.parse(gopayNoteQty, now: refNow);
        expect(parsed.sourceLabel, 'GoPay');
        expect(parsed.itemName, 'Kopi Susu Gula Aren');
        expect(parsed.quantity, 2);
        expect(parsed.amount, 18000);
        expect(
          parsed.nameCandidates,
          containsAll(<String>[
            'Kopi Susu Gula Aren',
            'Warung Kopi Kita',
            'Kopi Susu Gula Aren • Warung Kopi Kita',
          ]),
        );
        expect(parsed.date, DateTime(2026, 10, 25, 16, 40));
      },
    );

    test(
      'eliminates BRImo diagonal watermark gibberish ("bn br a bb") even when injected between label and value',
      () {
        expect(ReceiptParser.isGibberishOrWatermark('bn br a bb'), isTrue);
        expect(ReceiptParser.isGibberishOrWatermark('bn bri a bb'), isTrue);
        expect(ReceiptParser.isGibberishOrWatermark('BRI BRI BRI'), isTrue);
        expect(ReceiptParser.isGibberishOrWatermark('ii ll oo'), isTrue);
        expect(ReceiptParser.isGibberishOrWatermark('KFC'), isFalse);
        expect(ReceiptParser.isGibberishOrWatermark('RM Padang Sederhana'), isFalse);
        expect(ReceiptParser.isGibberishOrWatermark('Warung Bu Sri'), isFalse);

        const SharedReceiptPayload noisyBrimo = SharedReceiptPayload(
          hasAttachment: true,
          referrer: 'id.co.bri.brimo',
          ocrLines: <String>[
            'bn br a bb',
            'BRI BRI',
            'Transaksi Berhasil',
            '25 Okt 2026, 20:15:09 WIB',
            'Sumber Dana',
            'RHEZA FIRMANSYAH',
            '0123 **** **** 567',
            'Tujuan',
            'bn bri a bb',
            'TOKO SUKSES MAKMUR',
            'Nominal   Rp 65.000',
            'Biaya Admin   Rp 0',
            'Total Transaksi   Rp 65.000',
          ],
        );

        final ParsedReceipt parsed =
            ReceiptParser.parse(noisyBrimo, now: refNow);
        expect(parsed.sourceLabel, 'BRImo');
        expect(parsed.itemName, 'Toko Sukses Makmur');
        expect(parsed.amount, 65000);
        expect(parsed.quantity, 1);
        expect(parsed.isLikelyIncoming, isFalse);
      },
    );

    test(
      'handles BRImo standalone Nama row, SeaBank destination skip, and 2-column look-behind rescue',
      () {
        // 1. BRImo VA / E-Wallet Top-Up with standalone `Nama`
        const SharedReceiptPayload brimoNama = SharedReceiptPayload(
          referrer: 'id.co.bri.brimo',
          ocrLines: <String>[
            'Transaksi Berhasil',
            '25 Okt 2026, 13:10 WIB',
            'Sumber Dana   RHEZA FIRMANSYAH',
            '0123 **** **** 567',
            'Jenis Transaksi   Transfer Bank Lain',
            'Bank Tujuan   SeaBank',
            'Nomor Tujuan   901234567890',
            'Nama   SITI RAHMAWATI',
            'Total Transaksi   Rp 125.000',
          ],
        );
        final ParsedReceipt r1 = ReceiptParser.parse(brimoNama, now: refNow);
        expect(r1.sourceLabel, 'BRImo');
        expect(r1.itemName, 'Siti Rahmawati');
        expect(r1.amount, 125000);

        // 2. 2-column OCR split where right-column value sorted 1 line above its label
        const SharedReceiptPayload lookBehind = SharedReceiptPayload(
          referrer: 'id.co.bri.brimo',
          ocrLines: <String>[
            'Transaksi Berhasil',
            '25 Okt 2026, 18:00 WIB',
            'APOTEK KIMIA FARMA',
            'Nama Merchant',
            'Lokasi Merchant   BANDUNG',
            'Total Pembayaran   Rp 48.000',
          ],
        );
        final ParsedReceipt r2 = ReceiptParser.parse(lookBehind, now: refNow);
        expect(r2.itemName, 'Apotek Kimia Farma');
        expect(r2.amount, 48000);
      },
    );

    test(
      'detects incoming money across BRImo, GoPay, and BCA while ignoring cashback +Rp on expenses',
      () {
        // 1. GoPay Saldo Masuk
        const SharedReceiptPayload gopayIn = SharedReceiptPayload(
          referrer: 'com.gojek.gopay',
          ocrLines: <String>[
            'Saldo masuk',
            '+Rp175.000',
            '25 Okt 2026 · 14:22 WIB',
            'Dari   DIMAS PRATAMA',
            'Catatan   Patungan futsal',
          ],
        );
        final ParsedReceipt rGopay = ReceiptParser.parse(gopayIn, now: refNow);
        expect(rGopay.isLikelyIncoming, isTrue);
        expect(rGopay.itemName, 'Patungan futsal');
        expect(rGopay.nameCandidates, contains('Dimas Pratama'));
        expect(rGopay.amount, 175000);

        // 2. BRImo / Bank Transfer Masuk where Penerima is user's own account
        const SharedReceiptPayload brimoIn = SharedReceiptPayload(
          referrer: 'id.co.bri.brimo',
          ocrLines: <String>[
            'Dana Masuk',
            'Rp 750.000',
            '25 Okt 2026, 10:05 WIB',
            'Nama Pengirim   PT CIPTA KARYA DIGITAL',
            'Nama Penerima   RHEZA FIRMANSYAH',
            'Rekening Tujuan   0123 **** 567',
          ],
        );
        final ParsedReceipt rBrimo = ReceiptParser.parse(brimoIn, now: refNow);
        expect(rBrimo.isLikelyIncoming, isTrue);
        expect(rBrimo.itemName, 'PT Cipta Karya Digital');
        expect(rBrimo.nameCandidates, isNot(contains('Rheza Firmansyah')));
        expect(rBrimo.amount, 750000);

        // 3. Outgoing expense with +Rp cashback line must remain an expense
        const SharedReceiptPayload expenseWithCashback = SharedReceiptPayload(
          referrer: 'com.gojek.gopay',
          ocrLines: <String>[
            'Pembayaran berhasil',
            'Rp40.000',
            'BAKMI GM PONDOK INDAH',
            'Cashback   +Rp4.000 GoPay Coins',
            'Total pembayaran   Rp40.000',
          ],
        );
        final ParsedReceipt rOut =
            ReceiptParser.parse(expenseWithCashback, now: refNow);
        expect(rOut.isLikelyIncoming, isFalse);
        expect(rOut.itemName, 'Bakmi Gm Pondok Indah');
        expect(rOut.amount, 40000);
      },
    );
  });
}
