import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_extend/share_extend.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: MyHomePage(title: 'Long Range'),
    );
  }
}

class Connection extends StatefulWidget {
  const Connection({Key key, @required this.device}) : super(key: key);
  final BluetoothDevice device;

  @override
  _ConnectionState createState() => _ConnectionState();
}

class _ConnectionState extends State<Connection> {
  StreamSubscription deviceConnection;
  BluetoothCharacteristic characteristic;
  int packetCount = 0;
  int rssi = 0;
  bool crcError = false;
  bool connected = false;
  Timer timer;

  bool isRecording = false;
  TextStyle display = TextStyle(fontSize: 24);
  @override
  void initState() {
    connect();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
            backgroundColor: crcError ? Colors.redAccent : Colors.white,
            appBar: AppBar(
              actions: <Widget>[
                IconButton(
                  icon: Icon(Icons.share),
                  onPressed: () async {
                    ShareExtend.share(
                        await _localFile.then((file) => file.path), "file");
                  },
                )
              ],
            ),
            body: Column(
              // mainAxisAlignment: MainAxisAlignment.center,

              children: <Widget>[
                isRecording ? LinearProgressIndicator() : Container(),
                SizedBox(
                  height: 200,
                ),
                Center(
                  child: connected
                      ? Text(
                          "RSSI = $rssi \n\nPacket count = $packetCount \n\nCRC Error? $crcError",
                          style: display,
                        )
                      : Text("connecting to ${widget.device.name}"),
                ),
              ],
            ),
            floatingActionButton: !isRecording
                ? FloatingActionButton.extended(
                    label: Text("RECORD"),
                    icon: Icon(Icons.book),
                    onPressed: startRecording,
                    backgroundColor: Colors.black,
                  )
                : FloatingActionButton.extended(
                    label: Text("RECORDING"),
                    icon: Icon(Icons.book),
                    onPressed: () {},
                    backgroundColor: Colors.black,
                  )),
      ),
    );
  }

  readChar(BluetoothService service) async {
    if (widget.device != null) {
      BluetoothCharacteristic characteristic = service.characteristics[0];
      widget.device.readCharacteristic(characteristic).then((value) {
        ByteData data = ByteData.view(Uint8List.fromList(value).buffer);
        setState(() {
          rssi = data.getInt8(0);
          crcError = data.getUint8(1) > 0 ? true : false;
          packetCount = data.getUint16(2);
        });
        print("rssi = $rssi, packetCount = $packetCount, crcError = $crcError");
      });
    }
  }

  connect() {
    deviceConnection = flutterBlue.connect(widget.device).listen((s) async {
      if (s == BluetoothDeviceState.connected) {
        setState(() {
          connected = true;
        });
        List<BluetoothService> services =
            await widget.device.discoverServices();
        print("Connected to: ${widget.device.name}");
        timer = Timer.periodic(Duration(seconds: 1), (_) {
          print("reading");
          readChar(services[2]);
        });
      }
    });
  }

//  Recording
  startRecording() async {
    setState(() {
      isRecording = true;
    });

    var count = 0;
    dynamic avgRssi = 0;
    var crcCount = 0;
    int startCount = packetCount;
    int endCount = packetCount;

    while (count < 10) {
      await Future.delayed(Duration(seconds: 1));
      avgRssi = avgRssi + rssi;
      if (crcError) {
        crcCount++;
      }
      count++;
      if (count == 10) {
        endCount = packetCount;
        avgRssi = avgRssi / 10;
      }
    }

    Position location = await getLocation();

    writeToFile(DateTime.now().millisecondsSinceEpoch, location.latitude,
        location.longitude, avgRssi, startCount, endCount, crcCount);
  }

  Future<Position> getLocation() async {
    Position position = await Geolocator()
        .getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    print(position.toString());

    return position;
  }

// FILE WRITING

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File(
        '$path/long_range_${DateTime.now().toLocal().toString().split(' ')[0]}.csv');
  }

  void writeToFile(
      int millisecondsSinceEpoch,
      double latitude,
      double longitude,
      double avgRssi,
      int startCount,
      int endCount,
      int crcCount) async {
    final file = await _localFile;
    if (!await File(file.path).exists()) {
      file.writeAsStringSync(
          "Time stamp,Lat,Lng,Average RSSI,Start Count,End Count,Crc error count\n",
          mode: FileMode.append);
    }
    file
        .writeAsString(
            "$millisecondsSinceEpoch,$latitude,$longitude,${avgRssi.round()},$startCount,$endCount,$crcCount\n",
            mode: FileMode.append)
        .then((_) {
      setState(() {
        isRecording = false;
        print("Wrote $file");
        SnackBar snackbar = SnackBar(
          content: Text("Wrote to $file"),
          duration: Duration(seconds: 5),
        );

        Scaffold.of(context).showSnackBar(snackbar);
      });
    });
  }

  disconnect() {
    deviceConnection.cancel();
    timer.cancel();
  }

  Future<bool> _onWillPop() {
    disconnect();
    return Future.delayed(Duration(milliseconds: 200)).then((x) => true) ??
        true;
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

FlutterBlue flutterBlue = FlutterBlue.instance;

class _MyHomePageState extends State<MyHomePage> {
  Map<DeviceIdentifier, ScanResult> devices = {};
  var config = '';
  bool isScanning = false;
  StreamSubscription scanSubscription;
  scan() {
    setState(() {
      devices.clear();
      config = '';
      isScanning = true;
    });
    scanSubscription = flutterBlue
        .scan(
      timeout: const Duration(seconds: 5),
    )
        .listen((scanResult) {
      print(scanResult.advertisementData.manufacturerData);
      if (scanResult.device.name.toString().isNotEmpty) {
        setState(() {
          devices[scanResult.device.id] = scanResult;
        });
      }
    }, onDone: stopScan);
  }

  stopScan() {
    setState(() {
      isScanning = false;
    });
    scanSubscription.cancel();
  }

  // BluetoothDevice deviceG;

  // write(String e) async {
  //   await deviceG.writeCharacteristic(characteristic, hex.decode(e));
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: <Widget>[
          isScanning ? LinearProgressIndicator() : Container(),
          Expanded(
              flex: 1,
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                        title: Text(devices.values.toList()[index].device.name),
                        onTap: () {
                          stopScan();
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => Connection(
                                      device: devices.values
                                          .toList()[index]
                                          .device)));
                          // connect(devices.values.toList()[index].device),
                        });
                  },
                ),
              )),
        ],
      ),
      floatingActionButton: !isScanning
          ? FloatingActionButton.extended(
              backgroundColor: Colors.black,
              onPressed: scan,
              label: Text("SCAN"),
              icon: Icon(Icons.search),
            )
          : FloatingActionButton.extended(
              backgroundColor: Colors.black,
              onPressed: stopScan,
              label: Text("STOP SCAN"),
              icon: Icon(Icons.stop),
            ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
    );
  }
}
