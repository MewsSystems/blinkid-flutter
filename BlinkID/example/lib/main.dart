import 'package:blinkid_flutter/microblink_scanner.dart';
import 'package:flutter/material.dart';
import 'package:sample/document_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microblink Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlinkID Example')),
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final result = await context.scanDocument();
            if (!context.mounted || result == null) return;

            showDialog(
                context: context,
                builder: (_) => Dialog(
                      clipBehavior: Clip.antiAlias,
                      child: Scaffold(
                        appBar: AppBar(title: const Text('Result'), leading: const CloseButton()),
                        body: ListView.builder(
                          itemBuilder: (_, index) {
                            final item = result[index];

                            final name = switch (item) {
                              BlinkIdMultiSideRecognizerResult _ => 'BlinkIdMultiSideRecognizerResult',
                              _ => item.runtimeType.toString(),
                            };

                            return ExpansionTile(
                                title: Text(name),
                                children: item.formatted.entries.map((entry) {
                                  return ListTile(title: Text('${entry.key}: ${entry.value}'));
                                }).toList());
                          },
                          itemCount: result.length,
                        ),
                      ),
                    ));
          },
          child: const Text('Scan Document'),
        ),
      ),
    );
  }
}

extension on RecognizerResult {
  Map<String, dynamic> get formatted => switch (this) {
        BlinkIdMultiSideRecognizerResult result => {
            'First Name': result.firstName?.latin,
            'Last Name': result.lastName?.latin,
            'Age': result.age,
            'Nationality': result.nationality?.latin,
            'Nationality Code': result.nationalityIsoAlpha2,
            "Sex": result.sex?.latin,
            'Document Number': result.documentNumber?.latin,
            'Document Additional Number': result.documentAdditionalNumber?.latin,
            'Document Expiry Date': result.dateOfExpiry?.date?.dateTime,
            'Date of Birth': result.dateOfBirth?.date?.dateTime,
            'Date of Expiry': result.dateOfExpiry?.date?.dateTime,
            'Address': result.address?.latin,
          },
        _ => toJson(),
      };
}

extension on Date {
  DateTime? get dateTime {
    if (year == null || month == null || day == null) return null;

    return DateTime(year!, month!, day!);
  }
}
