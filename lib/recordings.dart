import 'package:flutter/material.dart';
import 'package:long_range/recordings_service.dart';
import 'package:provider/provider.dart';

class RecordingsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    List<RecordingFile> recordings =
        Provider.of<RecordingsService>(context).recordings;
    return Scaffold(
      body: Center(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemBuilder: (_, index) {
                  if (index < recordings.length) {
                    return ListTile(
                      title: Text(
                        recordings[index].fileName,
                        style: Theme.of(context).textTheme.body1,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                              icon: Icon(Icons.share),
                              onPressed: () {
                                RecordingsService()
                                    .shareProfile(recordings[index].filePath);
                              }),
                          IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                RecordingsService()
                                    .deleteProfile(recordings[index].filePath);
                              }),
                        ],
                      ),
                      onTap: () {},
                    );
                  }
                  if (index == recordings.length) {
                    return ListTile(title: SizedBox(height: 80.0));
                  }
                },
                itemCount: recordings.length + 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
