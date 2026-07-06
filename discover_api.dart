import 'dart:io';

void main() async {
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse('https://portal.uit.edu.vn'));
  final res = await req.close();
  final content = await res.transform(const SystemEncoding().decoder).join();

  final regex = RegExp(r'static/chunks/[a-zA-Z0-9_-]+\.js');
  final matches = regex.allMatches(content).map((m) => m.group(0)!).toSet();

  print('Found \${matches.length} JS chunks:');
  for (final chunk in matches) {
    print(chunk);
    final url = 'https://portal.uit.edu.vn/_next/\$chunk';
    final cReq = await client.getUrl(Uri.parse(url));
    final cRes = await cReq.close();
    final jsContent = await cRes
        .transform(const SystemEncoding().decoder)
        .join();

    // Look for /api/ paths
    final apiRegex = RegExp(
      r'["'
              "'" +
          r'](/api/[a-zA-Z0-9_/-]+)["' +
          "'" +
          r']',
    );
    final apiMatches = apiRegex.allMatches(jsContent);
    if (apiMatches.isNotEmpty) {
      print('  -> APIs found in \$chunk:');
      for (final am in apiMatches) {
        print('     \${am.group(1)}');
      }
    }
  }
}
