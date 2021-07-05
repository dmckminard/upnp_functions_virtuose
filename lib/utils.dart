import 'dart:convert';
import 'dart:typed_data';

int _getHeaderLength(Uint8List bytes) =>
    bytes.sublist(0, _getFirstFrameOffset(bytes) + 10).length;

int _getByteLengthFromDuration(int bitRate, Duration duration) =>
    (bitRate * 1000 * duration.inSeconds / 8).floor();

int _getFirstFrameOffset(Uint8List bytes) {
  var header = bytes.sublist(0, 10);
  var tag = header.sublist(0, 3);

  // Does the MP3 start with an ID3 tag?
  return latin1.decode(tag) == 'ID3' ? _processID3(header) : 0;
}

int _processID3(Uint8List bytes) {
  var headerSize =
      (bytes[6] << 21) + (bytes[7] << 14) + (bytes[8] << 7) + (bytes[9]);

  return headerSize + 10;
}

Uint8List cutMp3(Uint8List bytes, Duration startingPoint, int bitRate, Duration totalDuration) {
  return Uint8List.fromList(<int>[
    ...bytes.sublist(0, _getHeaderLength(bytes)).toList(),
    ...bytes
        .sublist(
        bytes.length -
            _getByteLengthFromDuration(
                bitRate, Duration(seconds: totalDuration.inSeconds - startingPoint.inSeconds < 0 ? 0 : totalDuration.inSeconds - startingPoint.inSeconds)),
        bytes.length)
        .toList(),
  ]);
}