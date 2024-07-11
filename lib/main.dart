import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:provider/provider.dart';
import 'package:bcrypt/bcrypt.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => TagReadModel(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TagReadPage(),
    );
  }
}

class TagReadModel with ChangeNotifier {
  String? tagUid;
  String? deviceToken; // This will now be the generated token
  bool isScanned = false;

  Future<void> handleTag(NfcTag tag) async {
    Uint8List? identifier = NfcA.from(tag)?.identifier ??
        NfcB.from(tag)?.identifier ??
        NfcF.from(tag)?.identifier ??
        NfcV.from(tag)?.identifier;

    if (identifier != null) {
      tagUid = identifier.toHexString();
      // Generate a unique token for the tag UID and use it as the device token
      deviceToken = generateUniqueToken(tagUid!);
      isScanned = true;
    } else {
      tagUid = 'Unknown UID';
      deviceToken = null;
    }

    notifyListeners();
  }

  Future<void> sendTagUid(BuildContext context) async {
    if (tagUid == null || tagUid == 'Unknown UID' || deviceToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No valid UID to send')),
      );
      return;
    }

    try {
      final response = await Dio().get(
        'https://vlsystem.co.ke/api/vls',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
        queryParameters: {
          'card_uid': tagUid,
          'device_token': deviceToken,
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User ID sent successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send User ID')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void reset() {
    tagUid = null;
    deviceToken = null;
    isScanned = false;
    notifyListeners();
  }

  String generateUniqueToken(String input) {
    final salt = BCrypt.gensalt();
    return BCrypt.hashpw(input, salt);
  }
}

class TagReadPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Provider.of<TagReadModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('RFID Card Scanner'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: model.isScanned ? null : () => startSession(context),
              child: Text('Start Scan'),
            ),
            SizedBox(height: 20),
            if (model.tagUid != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: model.tagUid,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'User ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      initialValue: model.deviceToken ?? 'Token not generated',
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Device Token',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            if (model.tagUid != null) ...[
              ElevatedButton(
                onPressed: () => model.sendTagUid(context),
                child: Text('Send'),
              ),
              ElevatedButton(
                onPressed: () => model.reset(),
                child: Text('Confirm'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void startSession(BuildContext context) {
    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      await Provider.of<TagReadModel>(context, listen: false).handleTag(tag);
      NfcManager.instance.stopSession();
    });
  }
}

extension on Uint8List {
  String toHexString() {
    return map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
  }
}
