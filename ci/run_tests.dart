import 'dart:convert';
import 'dart:io';

void main() async {
  final testNames = <int, String>{};

  // Start the test process with JSON reporter
  final process = await Process.start(
    'flutter',
    ['test', '--reporter', 'json'],
    runInShell: true,
  );

  process.stdout
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .listen((line) {
    if (line.trim().isEmpty) return;

    try {
      final event = jsonDecode(line);
      _handleEvent(event, testNames);
    } catch (e) {
      // Ignore non-JSON lines
    }
  });

  process.stderr
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .listen((line) {
    print("##teamcity[message text='${_escape(line)}' status='ERROR']");
  });

  final exitCode = await process.exitCode;
  exit(exitCode);
}

void _handleEvent(Map<String, dynamic> event, Map<int, String> testNames) {
  final type = event['type'];

  switch (type) {
    case 'testStart':
      final test = event['test'];
      if (test != null) {
        final id = test['id'];
        final name = _escape(test['name'] ?? '');

        // Ignore tests that are "loading <file path>"
        if (name.startsWith('loading ')) {
          return;
        }

        testNames[id] = name; // Store the test name for this ID
        print("##teamcity[testStarted name='$name']");
      }
      break;

    case 'testDone':
      final id = event['testID'];
      final name = testNames[id]; // Retrieve the test name using the ID

      if (name != null) {
        if (name.startsWith('loading ')) {
          return; // Ignore suite loading test completions
        }

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

      // Ignore suite loading events
      if (path.isNotEmpty) {
        return;
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