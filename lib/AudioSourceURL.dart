import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert' show htmlEscape;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:upnp/upnp.dart' as upnp;

import 'package:http/http.dart' as http;
import 'package:http_server/http_server.dart';
import 'package:mp3_info/mp3_info.dart';
import 'package:file/memory.dart';
import 'package:xml/xml.dart';

import 'package:path_provider/path_provider.dart';

import 'MediaData.dart';
import 'utils.dart';

class AudioSourceURL{
  Future<String> ipFuture;
  bool flagCatchErrors = true;
  upnp.Device _preferredDevice;
  List<upnp.Device> _otherDevices;
  List<upnp.Service> _otherServices;

  Future<upnp.Service> get _preferredService => _preferredDevice.getService('urn:upnp-org:serviceId:AVTransport');
  Future<upnp.Service> get _otherService => _otherDevices[0].getService('urn:upnp-org:serviceId:AVTransport');

  Future<List<upnp.Service>> _getOtherServices() async{
    List<upnp.Service> otherServices = List();
    for(int i = 0; i < _otherDevices.length; i++){
      var service = await _otherDevices[i].getService('urn:upnp-org:serviceId:AVTransport');
      otherServices.add(service);
    }

    _otherServices = otherServices;

    return otherServices;
  }

  AudioSourceURL(upnp.Device device){
    ipFuture = _getIp();
    _preferredDevice = device;
  }

  void setOtherDevices(List<upnp.Device> devices) async{
    _otherDevices = devices;
    await _getOtherServices();
    print("New other devices: $_otherDevices");
  }

  void castURL(url, MediaData mediaData, Duration start) async{
    var result = await http.get(url);
    print(result.body);
    var bytes = (await http.get(url)).bodyBytes;
    mediaData ??= MediaData(title: url);
    castBytes(bytes, mediaData, start);
  }

  void castBytes(Uint8List bytes, MediaData mediaData, Duration start) async{
    try {
      if (start != null) {
        var mp3 = MP3Processor.fromBytes(bytes);

        bytes = cutMp3(bytes, start, mp3.bitrate, mp3.duration);
        print("Duration: ${mp3.duration} / Bitrate: ${mp3.bitrate}");
      }

      _startServer(MemoryFileSystem().file('audio.mp3')..writeAsBytesSync(bytes), 8888, true);
      print("Passed start server");

      var result = await (await _preferredService).setCurrentURI('http://${await ipFuture}:8888', mediaData);

      if (result.isNotEmpty) debugPrint(result.toString());
    } catch (e) {
      print('castBytes(bytes, start, mediaData): ${e}');
      if (!flagCatchErrors) rethrow;
    }
  }

  void castDirectURL(String url, MediaData mediaData) async{
    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;
    arguments["CurrentURI"] = url;
    arguments["CurrentURIMetaData"] = (htmlEscape.convert(XmlDocument.parse(
        '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:sec="http://www.sec.co.kr/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
            '<item id="0" parentID="-1" restricted="false">'
            '<upnp:class>object.item.audioItem.musicTrack</upnp:class>'
            '<dc:title>${mediaData.title}</dc:title>'
            '<dc:creator>${mediaData.artist}</dc:creator>'
            '<upnp:artist>${mediaData.artist}</upnp:artist>'
            '<upnp:album>${mediaData.album}</upnp:album>'
            '<res protocolInfo="http-get:*:audio/mpeg:*">$url</res>'
            '</item>'
            '</DIDL-Lite>')
        .toString()));

    (await _preferredService).invokeAction("SetAVTransportURI", arguments);

    print("Request sent to ${_preferredDevice.friendlyName}");
  }

  void castLocal(String filePath, String fileName, MediaData mediaData, Duration start) async{
    final ByteData data = await rootBundle.load("$filePath/$fileName");

    Directory tempDir = await getTemporaryDirectory();

    Uint8List bytes = data.buffer.asUint8List();

    int port = 8888;
    var url = 'http://${await ipFuture}:$port';

    _startServer(MemoryFileSystem().file('audio.mp3')..writeAsBytesSync(bytes), port, true);
    print("Passed start server, current url is $url");

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;
    arguments["CurrentURI"] = url;
    arguments["CurrentURIMetaData"] = (htmlEscape.convert(XmlDocument.parse(
        '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:sec="http://www.sec.co.kr/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
            '<item id="0" parentID="-1" restricted="false">'
            '<upnp:class>object.item.audioItem.musicTrack</upnp:class>'
            '<dc:title>${mediaData.title}</dc:title>'
            '<dc:creator>${mediaData.artist}</dc:creator>'
            '<upnp:artist>${mediaData.artist}</upnp:artist>'
            '<upnp:album>${mediaData.album}</upnp:album>'
            '<res protocolInfo="http-get:*:audio/mpeg:*">$url</res>'
            '</item>'
            '</DIDL-Lite>')
        .toString()));

    (await _preferredService).invokeAction("SetAVTransportURI", arguments);

    print("Request sent to ${_preferredDevice.friendlyName}");
  }

  void castNextLocal(String filePath, String fileName, MediaData mediaData, int port) async{
    final ByteData data = await rootBundle.load("$filePath/$fileName");

    Directory tempDir = await getTemporaryDirectory();

    Uint8List bytes = data.buffer.asUint8List();

    var url = 'http://${await ipFuture}:$port';

    _startServer(MemoryFileSystem().file('audio.mp3')..writeAsBytesSync(bytes), port, true);
    print("Passed start server, current url is $url");

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;
    arguments["NextURI"] = url;
    arguments["NextURIMetaData"] = (htmlEscape.convert(XmlDocument.parse(
    '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:sec="http://www.sec.co.kr/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
    '<item id="0" parentID="-1" restricted="false">'
    '<upnp:class>object.item.audioItem.musicTrack</upnp:class>'
    '<dc:title>${mediaData.title}</dc:title>'
    '<dc:creator>${mediaData.artist}</dc:creator>'
    '<upnp:artist>${mediaData.artist}</upnp:artist>'
    '<upnp:album>${mediaData.album}</upnp:album>'
    '<res protocolInfo="http-get:*:audio/mpeg:*">$url</res>'
    '</item>'
    '</DIDL-Lite>')
        .toString()));

    (await _preferredService).invokeAction("SetNextAVTransportURI", arguments);

    print("Request sent to ${_preferredDevice.friendlyName}");
  }

  void castStream(String filePath, String fileName, MediaData mediaData) async{
    final ByteData data = await rootBundle.load("$filePath/$fileName");

    Int8List bytes = data.buffer.asInt8List();

    int port = 49152;
    var url = 'http://${await ipFuture}:$port';

    Stream<List<int>> stream = http.ByteStream.fromBytes(bytes);

    _startTCPSocket(stream.cast(), port, true);
    print("Passed start server, current url is $url");

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;
    arguments["CurrentURI"] = url;
    arguments["CurrentURIMetaData"] = (htmlEscape.convert(XmlDocument.parse(
        '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:sec="http://www.sec.co.kr/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
            '<item id="0" parentID="-1" restricted="false">'
            '<upnp:class>object.item.audioItem.musicTrack</upnp:class>'
            '<dc:title>${mediaData.title}</dc:title>'
            '<dc:creator>${mediaData.artist}</dc:creator>'
            '<upnp:artist>${mediaData.artist}</upnp:artist>'
            '<upnp:album>${mediaData.album}</upnp:album>'
            '<res protocolInfo="http-get:*:audio/mpeg:*">$url</res>'
            '</item>'
            '</DIDL-Lite>')
        .toString()));

    (await _preferredService).invokeAction("SetAVTransportURI", arguments);

    print("Request sent to ${_preferredDevice.friendlyName}");
  }

  void multicast(String filePath, String fileName, MediaData mediaData) async{
    final ByteData data = await rootBundle.load("$filePath/$fileName");

    Uint8List bytes = data.buffer.asUint8List();

    int port = 8888;
    var url = 'http://${await ipFuture}:$port';

    _startServer(MemoryFileSystem().file('audio.mp3')..writeAsBytesSync(bytes), port, true);
    print("Passed start server, current url is $url");

    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;
    arguments["CurrentURI"] = url;
    arguments["CurrentURIMetaData"] = (htmlEscape.convert(XmlDocument.parse(
        '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:sec="http://www.sec.co.kr/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
            '<item id="0" parentID="-1" restricted="false">'
            '<upnp:class>object.item.audioItem.musicTrack</upnp:class>'
            '<dc:title>${mediaData.title}</dc:title>'
            '<dc:creator>${mediaData.artist}</dc:creator>'
            '<upnp:artist>${mediaData.artist}</upnp:artist>'
            '<upnp:album>${mediaData.album}</upnp:album>'
            '<res protocolInfo="http-get:*:audio/mpeg:*">$url</res>'
            '</item>'
            '</DIDL-Lite>')
        .toString()));

    await (await _preferredService).invokeAction("SetAVTransportURI", arguments);

    if(_otherServices != null){
      for(int i = 0; i < _otherServices.length; i++){
        await (await _otherServices[i]).invokeAction("SetAVTransportURI", arguments);
      }
    }
  }

  void playMulticast() async{
    Map<String, dynamic> arguments = new Map();
    arguments["InstanceID"] = 0;
    arguments["Speed"] = 1;

    (await _preferredService).invokeAction("Play", arguments);
    for(int i = 0; i < _otherServices.length; i++){
      _otherServices[i].invokeAction("Play", arguments);
    }
  }

  void _startServer(File file, int port, bool shared){
    runZoned(() {
      HttpServer.bind(InternetAddress.anyIPv4, port, shared: shared).then((HttpServer server) {
        var vd = VirtualDirectory('.');
        vd.jailRoot = false;
        server.listen((request) {
          debugPrint('new request: ' + request.connectionInfo.remoteAddress.host);
          vd.serveFile(file, request);
        });
      }, onError: (e, stackTrace) => print('Oh noes! $e $stackTrace'));
    });
  }

  void _startTCPSocket(Stream<List<int>> stream, int port, bool shared){
    Stream<List<int>> broadcastStream = stream.asBroadcastStream();
    ServerSocket.bind(InternetAddress.anyIPv4, port, shared: shared).then((ServerSocket server){
      server.listen((Socket client) {
        client.addStream(broadcastStream);
      });
    });
  }

  Future<String> _getIp() async {
    for (var interface in await NetworkInterface.list()) {
      for (var a in interface.addresses) {
        if (a.type == InternetAddressType.IPv4) {
          return a.address;
        }
      }
    }

    return '';
  }
}

extension ServiceActions on upnp.Service{
  Future<Map<String, dynamic>> setCurrentURI(String url, MediaData mediaData) =>
      invokeEditedAction('SetAVTransportURI', {
        'InstanceID': '0',
        'CurrentURI': url,
        'CurrentURIMetaData': (htmlEscape.convert(XmlDocument.parse(
            '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:sec="http://www.sec.co.kr/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
                '<item id="0" parentID="-1" restricted="false">'
                '<upnp:class>object.item.audioItem.musicTrack</upnp:class>'
                '<dc:title>${mediaData.title}</dc:title>'
                '<dc:creator>${mediaData.artist}</dc:creator>'
                '<upnp:artist>${mediaData.artist}</upnp:artist>'
                '<upnp:album>${mediaData.album}</upnp:album>'
                '<res protocolInfo="http-get:*:audio/mpeg:*">$url</res>'
                '</item>'
                '</DIDL-Lite>')
            .toString()))
      });

  Future<Map<String, String>> invokeEditedAction(
      String name,
      Map<String, dynamic> args) async {
    return await actions.firstWhere((it) => it.name == name).invoke(args);
  }
}

extension EditedAction on upnp.Action{
  Future<Map<String, String>> invokeEdited(Map<String, dynamic> args) async {
    var param = '  <u:${name} xmlns:u="${service.type}">' + args.keys.map((it) {
      String argsIt = args[it].toString();
      argsIt = argsIt.replaceAll("&quot;", '"');
      argsIt = argsIt.replaceAll("&#47;", '/');
      return "<${it}>${argsIt}</${it}>";
    }).join("\n") + '</u:${name}>\n';

    var result = await service.sendToControlUrl(name, param);
    var doc = XmlDocument.parse(result);
    XmlElement response = doc
        .rootElement;

    if (response.name.local != "Body") {
      response = response.children.firstWhere((x) => x is XmlElement);
    }

    if (const bool.fromEnvironment("upnp.action.show_response", defaultValue: false)) {
      print("Got Action Response: ${response.toXmlString()}");
    }

    if (response is XmlElement
        && !response.name.local.contains("Response") &&
        response.children.length > 1) {
      response = response.children[1];
    }

    if (response.children.length == 1) {
      var d = response.children[0];

      if (d is XmlElement) {
        if (d.name.local.contains("Response")) {
          response = d;
        }
      }
    }

    if (const bool.fromEnvironment("upnp.action.show_response", defaultValue: false)) {
      print("Got Action Response (Real): ${response.toXmlString()}");
    }

    List<XmlElement> results = response.children
        .whereType<XmlElement>()
        .toList();
    var map = <String, String>{};
    for (XmlElement r in results) {
      map[r.name.local] = r.text;
    }
    return map;
  }
}