import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:portfolio_app/services/network_request_queue.dart';

void main() {
  test('active request is queued on connection loss and auto-resumes', () {
    fakeAsync((async) {
      final queue = RequestQueue(online: false);
      queue.setOnline(true, interface: 'Wi-Fi');
      queue.start();
      queue.addRequest();

      expect(queue.activeCount, 1);

      queue.setOnline(false, interface: 'Offline');
      expect(queue.queuedCount, 1);
      expect(queue.activeCount, 0);
      expect(queue.events.any((e) => e.contains('queued')), isTrue);

      queue.setOnline(true, interface: 'Cellular');
      expect(queue.activeCount, 1);

      async.elapse(const Duration(seconds: 15));
      expect(queue.doneCount, 1);
      expect(queue.queuedCount, 0);

      queue.dispose();
    });
  });

  test('requests started offline stay queued and drain after recovery', () {
    fakeAsync((async) {
      final queue = RequestQueue(online: false);
      queue.setOnline(false, interface: 'Offline');
      queue.start();
      queue.addRequest();
      queue.addRequest();

      expect(queue.queuedCount, 2);
      expect(queue.activeCount, 0);

      queue.setOnline(true, interface: 'Wi-Fi');
      expect(queue.activeCount, 1);

      async.elapse(const Duration(seconds: 30));
      expect(queue.doneCount, 2);
      expect(queue.queuedCount, 0);

      queue.dispose();
    });
  });

  test('adding a request while one is active queues it, not hijacking', () {
    fakeAsync((async) {
      final queue = RequestQueue(online: false);
      queue.setOnline(true, interface: 'Wi-Fi');
      queue.start();
      queue.addRequest();
      queue.addRequest();

      expect(queue.activeCount, 1);
      expect(queue.queuedCount, 1);

      async.elapse(const Duration(seconds: 30));
      expect(queue.doneCount, 2);
      expect(queue.activeCount, 0);
      expect(queue.queuedCount, 0);

      queue.dispose();
    });
  });
}