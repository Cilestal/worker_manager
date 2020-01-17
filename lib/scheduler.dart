import 'package:async/async.dart';

import 'executor.dart';
import 'isolate.dart';

abstract class Scheduler {
  void manageQueue<O>(Task<Object, Object, Object, Object, Object, O> task);

  Future<void> warmUp();

  factory Scheduler.regular() => RegularScheduler();
}

class RegularScheduler implements Scheduler {
  final isolates = <WorkerIsolate>[];
  final queue = <Task>[];

  @override
  void manageQueue<O>(Task<Object, Object, Object, Object, Object, O> task) {
    if (isolates.where((isolate) => !isolate.isBusy && !isolate.isInitialized).length ==
        isolates.length) {
      _warmUpFirst().then((_) {
        if (queue.contains(task)) manageQueue<O>(task);
      });
    } else {
      final availableWorker = isolates
          .firstWhere((worker) => !worker.isBusy && worker.isInitialized, orElse: () => null);
      if (availableWorker != null) {
        queue.remove(task);
        availableWorker.work<O>(task: task).listen((result) {
          result is ErrorResult
              ? task.completer.completeError(result.error)
              : task.completer.complete(result.asValue.value);
          if (queue.isNotEmpty) manageQueue<O>(queue.first);
        });
      }
    }
  }

  Future<void> _warmUpFirst() => isolates[0].initializationCompleter.future;

  @override
  Future<void> warmUp() =>
      Future.wait(isolates.map((isolate) => isolate.initializationCompleter.future).toList());
}
