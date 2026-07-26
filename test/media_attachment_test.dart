import 'package:ababilx/features/crm/data/models/crm_models.dart';
import 'package:ababilx/features/wall/data/models/wall_models.dart';
import 'package:ababilx/shared/media/picked_media_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps common CRM and Wall attachment file types', () {
    expect(contentTypeForFileName('receipt.pdf'), 'application/pdf');
    expect(contentTypeForFileName('voice-message-8s.m4a'), 'audio/mp4');
    expect(
      contentTypeForFileName('proposal.docx'),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(
      contentTypeForFileName('unknown.custom'),
      'application/octet-stream',
    );
  });

  test('detects audio attachments from MIME type or file extension', () {
    const wallAudio = WallAttachment(
      id: 'wall-audio',
      postId: 'post',
      fileName: 'voice-message-4s.m4a',
      fileUrl: 'https://example.com/voice.m4a',
      contentType: 'application/octet-stream',
      sizeBytes: 1024,
      uploadedBy: 'user',
      createdAt: '',
    );
    const crmAudio = CrmDocument(
      id: 'crm-audio',
      leadId: 'lead',
      contactId: 'contact',
      fileUrl: 'https://example.com/voice',
      fileName: 'voice',
      mimeType: 'audio/mp4',
    );

    expect(wallAudio.isAudio, isTrue);
    expect(crmAudio.isAudio, isTrue);
  });

  test('payment receipt and invoice fields serialize for web API parity', () {
    const payment = CrmLeadPaymentInput(
      amount: 1200,
      paidAt: '2026-07-26T00:00:00Z',
      invoiceReference: 'INV-204',
      note: 'Paid by bank transfer',
      receiptDocumentId: 'document-id',
    );

    expect(payment.toJson(), containsPair('invoice_reference', 'INV-204'));
    expect(
      payment.toJson(),
      containsPair('receipt_document_id', 'document-id'),
    );
  });
}
