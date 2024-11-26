import 'dart:convert';
import 'dart:io';

void main() async {
  final testNames = <int, String>{};
  final activeTests = <int>{}; // Track active test IDs

  // Start the test process with JSON reporter and sequential execution
  final process = await Process.start(
    'flutter',
    ['test', '--reporter', 'json', '--concurrency=1'],
    runInShell: true,
  );

  // Process JSON output line by line
  process.stdout
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .listen((line) {
    if (line.trim().isEmpty) return;

    try {
      final event = jsonDecode(line);
      _handleEvent(event, testNames, activeTests);
    } catch (e) {
      // Ignore non-JSON lines
    }
  });

  // Log errors from stderr
  process.stderr
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .listen((line) {
    print("##teamcity[message text='${_escape(line)}' status='ERROR']");
  });

  // Wait for the test process to exit
  final exitCode = await process.exitCode;
  exit(exitCode);
}

void _handleEvent(
    Map<String, dynamic> event, Map<int, String> testNames, Set<int> activeTests) {
  final type = event['type'];

  switch (type) {
    case 'testStart':
      final test = event['test'];
      if (test != null) {
        final id = test['id'];
        final name = _escape(test['name'] ?? '');

        if (name.startsWith('loading ')) {
          return; // Ignore loading events
        }

        testNames[id] = name; // Store the test name for this ID
        activeTests.add(id); // Mark test as active
        print("##teamcity[testStarted name='$name']");
      }
      break;

    case 'testDone':
      final id = event['testID'];
      final name = testNames[id]; // Retrieve the test name using the ID

      if (name != null && activeTests.contains(id)) {
        // Ensure test is active before marking it as finished
        if (event['result'] == 'error' || event['result'] == 'failure') {
          final message = _escape(event['error'] ?? '');
          final details = _escape(event['stackTrace'] ?? '');

          print(
            "##teamcity[testFailed name='$name' message='$message' details='$details']",
          );
        } else if (event['skipped'] == true) {
          print("##teamcity[testIgnored name='$name']");
        }

        print("##teamcity[testFinished name='$name']");
        activeTests.remove(id); // Mark test as finished
      }
      break;

    case 'error':
      final message = _escape(event['error'] ?? '');
      final details = _escape(event['stackTrace'] ?? '');

      print("##teamcity[message text='$message' errorDetails='$details' status='ERROR']");
      break;

    case 'suite':
      final suite = event['suite'];
      final path = suite['path'] ?? '';

      if (path.isNotEmpty) {
        return; // Ignore suite loading events
      }
      break;

    case 'print':
      final message = _escape(event['message'] ?? '');
      print(message);
      print("##teamcity[message text='$message']");
      break;

    default:
      break;
  }
}

String _escape(String text) {
  if (text == null) return '';
  return text
      .replaceAll('|', '||')
      .replaceAll("'", "|'")
      .replaceAll('\n', '|n')
      .replaceAll('\r', '|r')
      .replaceAll('[', '|[')
      .replaceAll(']', '|]')
      .replaceAll('\u0085', '|x') // Next Line
      .replaceAll('\u2028', '|l') // Line Separator
      .replaceAll('\u2029', '|p'); // Paragraph Separator
}