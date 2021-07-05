import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:upnp/upnp.dart' as upnp;
import 'package:upnp_given_examples/AudioSourceURL.dart';

import 'MediaData.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'UPNP trials'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const String UPNP_DEVICE_RENDERER = "urn:schemas-upnp-org:device:MediaRenderer:1";
  static const String UPNP_SERVICE_AVTRANSPORT = "urn:schemas-upnp-org:service:AVTransport:1";
  static const String UPNP_SERVICE_CONTROL = "urn:schemas-upnp-org:service:RenderingControl:1";

  static const String PREFERRED_DEVICE_FRIENDLY_NAME = "9";
  static const String OTHER_DEVICE_FRIENDLY_NAME = "8";
  static const List<String> OTHER_DEVICES_FRIENDLY_NAMES = ["8", "10", "12"];

  String _currentlyPlayingURL = "none.";
  String _currentDevice = "No devices scanned yet.";

  var disc = new upnp.DeviceDiscoverer();
  List<upnp.Device> _devices;
  upnp.Device _preferredDevice;

  AudioSourceURL _audioSourceURL;

  int _currentAudioPart = 0;

  _MyHomePageState(){
    _devices = [];

  }

  void _refreshDevices() async{
    _devices.clear();

    await disc.start(ipv6: false);

    disc.quickDiscoverClients().listen(
            (client) async{
          try{
            var currentDevice = await client.getDevice();
            _devices.add(currentDevice);

            displayDeviceServices(currentDevice);

            if(currentDevice.friendlyName == PREFERRED_DEVICE_FRIENDLY_NAME){
              _preferredDevice = currentDevice;
              setState(() {
                _currentDevice = _preferredDevice.friendlyName;
              });
              _audioSourceURL = new AudioSourceURL(currentDevice);
            }
          } catch(e, stack){
            print("ERROR: ${e} - ${client.location}");
            print(stack);
          }

          setState(() {
            _devices = _devices;
          });
        }
    );
  }

  void displayDeviceServices(upnp.Device device){
    print("--------------------------\n############################\n--------------------------");
    print("${device.friendlyName}: ${device.url}");

    for(var service in device.services){
      print("****NEW SERVICE****");
      print("ID: ${service.id}");
      print("Type: ${service.type}");
      //print("C.URL: ${svc.controlUrl}");
    }
  }

  void _showDeviceListLength(){
    print(_devices.length);
  }

  void _play() async{
    if(_preferredDevice == null){
      return;
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_AVTRANSPORT);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;
    arguments["Speed"] = 1;

    service.invokeAction("Play", arguments);
  }

  void _pause() async{
    if(_preferredDevice == null){
      return;
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_AVTRANSPORT);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;

    service.invokeAction("Pause", arguments);
  }

  void _stop() async{
    if(_preferredDevice == null){
      return;
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_AVTRANSPORT);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;

    service.invokeAction("Stop", arguments);
  }

  void _previous() async{
    if(_preferredDevice == null){
      return;
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_AVTRANSPORT);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;

    service.invokeAction("Previous", arguments);
  }

  void _next() async{
    if(_preferredDevice == null){
      return;
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_AVTRANSPORT);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;

    service.invokeAction("Next", arguments);
  }

  void _setVolume(int volume) async{
    if(_preferredDevice == null){
      return;
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_CONTROL);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    if(service == null){ return; }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;
    arguments["Channel"] = "Master";
    arguments["DesiredVolume"] = volume;

    service.invokeAction("SetVolume", arguments);
  }

  Future<int> _getVolume() async{
    if(_preferredDevice == null){
      return -1;
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_CONTROL);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;
    arguments["Channel"] = "Master";

    var result = await service.invokeAction("GetVolume", arguments);
    print("Current volume: ${result["CurrentVolume"]}");
    return int.parse(result["CurrentVolume"]);
  }

  void _upperVolume() async{
    int currentVolume = await _getVolume();
    _setVolume(currentVolume + 10);
  }

  void _lowerVolume() async{
    int currentVolume = await _getVolume();
    _setVolume(currentVolume - 10);
  }

  Future<Map<String, dynamic>> _getMediaInfo() async{
    if(_preferredDevice == null){
      return null;
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_AVTRANSPORT);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    if(service == null){ return null; }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;

    var result = await service.invokeAction("GetMediaInfo", arguments);
    print("MediaInfo: $result");
    return(result);
  }

  Future<String> _getMediaDuration() async{
    Map<String, dynamic> result = await _getMediaInfo();
    if(result == null){ return("Null"); }
    return(result["MediaDuration"]);
  }

  void _testMediaDuration() async{
    print("Current media duration: ${await _getMediaDuration()}");
  }

  Future<String> _getProgress() async{
    if(_preferredDevice == null){
      return("Null");
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_AVTRANSPORT);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    if(service == null){ return("Null"); }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;

    var result = await service.invokeAction("GetPositionInfo", arguments);
    print("Current progress: ${result["RelTime"]}");
    return(result["RelTime"]);
  }

  void _setProgress() async{
    if(_preferredDevice == null){
      return;
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_AVTRANSPORT);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    if(service == null){ return; }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;
    arguments["Unit"] = "REL_TIME";
    arguments["Target"] = "00:01:00";

    service.invokeAction("Seek", arguments);
  }

  void _castFromURL(String url){
    _audioSourceURL.castURL(url, MediaData(title: 'testTitle', album: 'album'), const Duration(seconds: 30));
    setState(() {
      _currentlyPlayingURL = url;
    });
  }

  void _castDirectFromURL(){
    _audioSourceURL.castDirectURL("http://us2.internet-radio.com:8085/;", MediaData(title: 'testTitle', album: 'album'));
  }

  Future<String> _getTransportState() async{
    if(_preferredDevice == null){
      return "UNKNOWN";
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_AVTRANSPORT);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    if(service == null){ return "UNKNOWN"; }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;

    var result = await service.invokeAction("GetTransportInfo", arguments);
    return(result["CurrentTransportState"]);
  }

  void _testTransportState() async{
    print("Current TransportState: ${await _getTransportState()}");
  }

  Future<bool> _isSongOver() async{
    var mediaDuration = await _getMediaDuration();
    var currentProgress = await _getProgress();

    return(mediaDuration == currentProgress);
  }

  void _testIsSongOver() async{
    print("Song is over? -> ${await _isSongOver()}");
  }

  void _playFromFile(){
    //_audioSourceURL.testCastLocal("assets", "sample4.mp3", MediaData(title: 'testTitle', album: 'album'), Duration(seconds: 30));
    //_audioSourceURL.castLocal("assets", "sample5MB.mp3", MediaData(title: 'testTitle', album: 'album'), Duration(seconds: 30));
    _audioSourceURL.castLocal("assets", "Norah_Jones-12-Nightingale.flac", MediaData(title: 'testTitle', album: 'album'), Duration(seconds: 30));
    //_audioSourceURL.testCastLocal("assets/HighRes", "2-bad_guy.flac", MediaData(title: 'testTitle', album: 'album'), Duration(seconds: 30));
  }

  void _testCastQueue(){
    /*for(int i = 0; i < _numberOfAudioParts; i++){
      _audioSourceURL.castNextLocal(AUDIO_PARTS_FOLDER, _listOfAudioParts[i], MediaData(title: 'testTitle', album: 'album'), 49152+i);
    }*/
    _audioSourceURL.castNextLocal("assets", "sample4.mp3", MediaData(title: 'testTitle', album: 'album'), 49152);
  }

  void _testCastStream(){
    _audioSourceURL.castStream("assets", "sample5MB.mp3", MediaData(title: 'testTitle', album: 'album'));
  }

  void _testMultiCast(){
    List<upnp.Device> selectedDevices = [];
    for(int i = 0; i < _devices.length; i++){
      if(OTHER_DEVICES_FRIENDLY_NAMES.contains(_devices.elementAt(i).friendlyName)){
        selectedDevices.add(_devices.elementAt(i));
      }
    }
    _audioSourceURL.setOtherDevices(selectedDevices);

    _audioSourceURL.multicast("assets", "Norah_Jones-12-Nightingale.flac", MediaData(title: 'testTitle', album: 'album'));
  }

  void _playMulticast(){
    _audioSourceURL.playMulticast();
  }

  /*void _setMute(bool state) async{
    if(_preferredDevice == null){
      return;
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_CONTROL);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;
    arguments["Channel"] = "Master";
    arguments["DesiredMute"] = state;

    await service.invokeAction("SetMute", arguments);
  }

  Future<int> _getMute() async{
    if(_preferredDevice == null){
      return -1;
    }

    upnp.Service service;
    try{
      service = await _preferredDevice.getService(UPNP_SERVICE_CONTROL);
    } catch(e){
      print("ERROR WHILE FETCHING SERVICE: ${e}");
    }

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;
    arguments["Channel"] = "Master";
    arguments["CurrentMute"] = null;

    var result = await service.invokeAction("GetMute", arguments);
    print("Current mute: ${result["CurrentMute"]}");

    return int.parse(result["CurrentMute"]);
  }

  void _toggleMute() async{
    int currentState = await _getMute();
    bool nextState;

    if(currentState == 1){
      nextState = false;
    } else if(currentState == 0){
      nextState = true;
    } else{
      return;
    }
    _setMute(nextState);
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
                "Current UPnP device: $_currentDevice"
            ),
            /*Text(
              "This version ONLY controls ONE device, here device '${PREFERRED_DEVICE_FRIENDLY_NAME}'",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15
              ),
            ),*/
            /*Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _showDeviceListLength, child: Icon(Icons.remove_red_eye)),
              ],
            ),*/
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _play, child: Icon(Icons.play_arrow_outlined)),
                ElevatedButton(onPressed: _pause, child: Icon(Icons.pause)),
                ElevatedButton(onPressed: _stop, child: Icon(Icons.stop)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _previous, child: Row(children: [Text("Prev"), Icon(Icons.skip_previous)])),
                ElevatedButton(onPressed: _next, child: Row(children: [Text("Next"), Icon(Icons.skip_next)])),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _lowerVolume, child: Row(children: [Text("-10"), Icon(Icons.volume_down_outlined)],)),
                ElevatedButton(onPressed: _upperVolume, child: Row(children: [Text("+10"), Icon(Icons.volume_up_outlined)],)),
                ElevatedButton(onPressed: _getVolume, child: Row(children: [Text("Get volume")],)),
              ],
            ),
            //Mute part
            /*Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _toggleMute, child: Icon(Icons.volume_off)),
                ElevatedButton(onPressed: _getMute, child: Row(children: [Icon(Icons.get_app), Icon(Icons.volume_off)],)),
              ],
            ),*/
            Text(
                "Currently casting this url: $_currentlyPlayingURL"
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //ElevatedButton(onPressed: _getProgress, child: Icon(Icons.subdirectory_arrow_right_sharp)),
                //ElevatedButton(onPressed: _setProgress, child: Icon(Icons.double_arrow)),
                ElevatedButton(onPressed: () => { _castFromURL('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3') }, child: Row(children: [Text("Cast URL"), Icon(Icons.tap_and_play)],)),
                ElevatedButton(onPressed: _playFromFile, child: Row(children: [Text("Cast asset File"), Icon(Icons.tap_and_play)],)),
                ElevatedButton(onPressed: _castDirectFromURL, child: Row(children: [Text("Direct cast"), Icon(Icons.tap_and_play)],)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _testTransportState, child: Row(children: [Text("Get Transport Info"), Icon(CupertinoIcons.arrow_down_square)],)),
                ElevatedButton(onPressed: _getMediaInfo, child: Row(children: [Text("Get Media Info"), Icon(CupertinoIcons.arrow_down_square)],)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _getProgress, child: Row(children: [Text("Get Progress"), Icon(CupertinoIcons.arrow_uturn_right)],)),
                ElevatedButton(onPressed: _testMediaDuration, child: Row(children: [Text("Get Media Duration"), Icon(CupertinoIcons.arrow_left_right)],)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _testIsSongOver, child: Row(children: [Text("Is Song Over?"), Icon(CupertinoIcons.dial)],)),
                //ElevatedButton(onPressed: _startAudioPartRoutine, child: Row(children: [Text("Start casting parts"), Icon(CupertinoIcons.arrow_up)],)),
                ElevatedButton(onPressed: _testCastQueue, child: Row(children: [Text("Cast queue"), Icon(CupertinoIcons.arrow_up_bin_fill)],)),
              ],
            ),
            Text("Streaming"),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _testCastStream, child: Row(children: [Text("Cast Stream"), Icon(Icons.tap_and_play)],)),
                ElevatedButton(onPressed: _testMultiCast, child: Row(children: [Text("Multicast"), Icon(Icons.tap_and_play)],)),
                ElevatedButton(onPressed: _playMulticast, child: Row(children: [Text("Play multicast"), Icon(Icons.tap_and_play)],)),
              ],
            ),
            Text("List of UPNP compatible device:"),
            Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: _devices.length,
                  itemBuilder: (BuildContext context, int index){
                    return Container(
                      height: 20,
                      color: Colors.blueGrey,
                      child: Text("${_devices[index].friendlyName}"),
                    );
                  },
                )
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshDevices,
        tooltip: 'Increment',
        child: Icon(Icons.refresh_outlined),
      ),
    );
  }
}