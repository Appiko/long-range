import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_extend/share_extend.dart';

class RecordingFile {
  final String filePath;
  String fileName;

  RecordingFile({
    @required this.filePath,
  }) {
    var realFileName = basename(this.filePath);
    fileName = realFileName.split('​')[0];
  }
}

class RecordingsService with ChangeNotifier {
  List<RecordingFile> recordings = [];

  RecordingsService() {
    fetchProfiles();
  }

  fetchProfiles() async {
    await getProfiles();
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  _generateFilePath(String recordingName) async {
    final path = await _localPath;
    return "$path/$recordingName​${DateTime.now().millisecondsSinceEpoch}";
  }

  addProfile({@required recordingName}) async {
    // seprated by a Zero width space character U+200B `​`​
    // Directory("$path").createSync();
    File profileFile = File(await _generateFilePath(recordingName));
    profileFile.writeAsStringSync("123");
    getProfiles();
  }

  deleteProfile(String filePath) {
    File file = File(filePath);
    file.delete();
    getProfiles();
  }

  shareProfile(String filePath) async {
    ShareExtend.share(filePath, "file");
  }

  getProfiles() async {
    final dir = Directory(await _localPath);
    recordings.clear();
    if (dir.existsSync()) {
      dir.listSync().forEach((FileSystemEntity f) {
        recordings.add(RecordingFile(
          filePath: f.path,
        ));
      });
      notifyListeners();
    }
  }
}
