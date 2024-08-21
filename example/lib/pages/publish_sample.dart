import 'dart:async';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_whip/flutter_whip.dart';
import 'package:mic_volume/mic_volume.dart';

class WhipPublishSample extends StatefulWidget {
  static String tag = 'whip_publish_sample';

  @override
  _WhipPublishSampleState createState() => _WhipPublishSampleState();
}

class _WhipPublishSampleState extends State<WhipPublishSample> {
  String stateStr = 'init';

  bool _connecting = false;
  bool _isMuted = false;
  final _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  TextEditingController _serverController = TextEditingController();
  late WHIP _whip;
  Timer? _timer;
  double _volumeLevel = 0.0;
  StreamSubscription? _recorderSubscription;
  FlutterSoundRecorder? _recorder;
  Timer? timer;
  final micVolumplugin = MicVolume();
  @override
  void deactivate() {
    super.deactivate();
    _localRenderer.dispose();
    _timer?.cancel();
  }

  @override
  void initState() {
    super.initState();
    initRenderers();
    _loadSettings();
  }

  void initRenderers() async {
    await _localRenderer.initialize();
  }

  void muteMic() {}

  void _loadSettings() async {
    this.setState(() {
      _serverController.text =
          'https://dev-rtc.radiotech.vn/rtc/v1/whip/?app=live&stream=manhvv';
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  void _connect() async {
    final url = _serverController.text;

    if (url.isEmpty) {
      return;
    }

    // _saveSettings();

    _whip = WHIP(url: url);

    _whip.onState = (WhipState state) {
      setState(() {
        switch (state) {
          case WhipState.kNew:
            stateStr = 'New';
            break;
          case WhipState.kInitialized:
            stateStr = 'Initialized';
            break;
          case WhipState.kConnecting:
            stateStr = 'Connecting';
            break;
          case WhipState.kConnected:
            stateStr = 'Connected';
            break;
          case WhipState.kDisconnected:
            stateStr = 'Closed';
            break;
          case WhipState.kFailure:
            stateStr = 'Failure: \n${_whip.lastError.toString()}';
            break;
        }
      });
    };
    try {
      var stream =
          await navigator.mediaDevices.getUserMedia(K_LOCAL_MEDIA_CONTRAINT);

      _localStream = stream;

      _localRenderer.srcObject = _localStream;
      await _whip.initlize(mode: WhipMode.kSend, stream: _localStream);
      await _whip.connect();
      // micVolumplugin.getmicVolumplugin();
      micVolumplugin.startCheckVolume().then((_) {
        timer = Timer.periodic(Duration(milliseconds: 100), (e) async {
          _volumeLevel = await micVolumplugin.getMicVolume() ?? _volumeLevel;
          setState(() {});
        });
      });
    } catch (e) {
      print('connect: error => ' + e.toString());
      _localRenderer.srcObject = null;
      _localStream?.dispose();
      return;
    }
    if (!mounted) return;

    setState(() {
      _connecting = true;
    });
  }

  void _disconnect() async {
    try {
      if (kIsWeb) {
        _localStream?.getTracks().forEach((track) => track.stop());
      }
      await _localStream?.dispose();
      _localRenderer.srcObject = null;
      _whip.close();
      setState(() {
        _connecting = false;
      });
      micVolumplugin.stopCheckVolume();
    } catch (e) {
      print(e.toString());
    }
  }

  void _toggleCamera() async {
    if (_localStream == null) throw Exception('Stream is not initialized');
    final videoTrack = _localStream!
        .getVideoTracks()
        .firstWhere((track) => track.kind == 'video');
    await Helper.switchCamera(videoTrack);
  }

  void _toggleMute() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;

      setState(() {
        _isMuted = !_isMuted;
        audioTrack.enabled = !_isMuted;
        if (_isMuted) {
          timer?.cancel();
          micVolumplugin.stopCheckVolume();
        } else {
          micVolumplugin.startCheckVolume().then((_) {
            timer = Timer.periodic(Duration(milliseconds: 100), (e) async {
              print('Get volume');
              _volumeLevel =
                  await micVolumplugin.getMicVolume() ?? _volumeLevel;
              setState(() {});
            });
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Stream'), actions: <Widget>[
        if (_connecting)
          IconButton(
            icon: Icon(Icons.switch_video),
            onPressed: _toggleCamera,
          ),
      ]),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (_connecting)
                  Center(
                    child: SizedBox(
                      height: 1,
                      width: 1,
                      child: Container(
                        margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                        decoration: BoxDecoration(color: Colors.black54),
                        child: RTCVideoView(_localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover),
                      ),
                    ),
                  ),
                if (_connecting)
                  VolumeIndicator(
                    isMute: !(_volumeLevel >= 0 && !_isMuted),
                    volumeLevel: _volumeLevel,
                  ),
                IconButton(
                  splashRadius: 30,
                  color: Colors.cyan[800],
                  icon: Icon(
                    _isMuted ? Icons.mic_off : Icons.mic,
                    size: 30,
                  ),
                  onPressed: _toggleMute,
                )
              ]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _connecting ? _disconnect : _connect,
        tooltip: _connecting ? 'Hangup' : 'Call',
        child: Icon(_connecting ? Icons.call_end : Icons.phone),
      ),
    );
  }
}

class VolumeIndicator extends StatefulWidget {
  final bool isMute;
  final double volumeLevel;
  const VolumeIndicator(
      {super.key, required this.isMute, required this.volumeLevel});
  @override
  _VolumeIndicatorState createState() => _VolumeIndicatorState();
}

class _VolumeIndicatorState extends State<VolumeIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    if (!widget.isMute) {
      _controller = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      )..repeat();
      _animation = Tween<double>(begin: 0, end: 100).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void didUpdateWidget(covariant VolumeIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMute == true) {
      _controller.reset();
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              painter: VolumePainter(_animation.value),
              child: SizedBox(
                width: 200,
                height: 200,
              ),
            ),
            AnimatedContainer(
              curve: Curves.easeInOut,
              duration: Duration(milliseconds: 300),
              height: widget.isMute ? 100 : 100 + (100 * widget.volumeLevel),
              width: widget.isMute ? 100 : 100 + (100 * widget.volumeLevel),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            AnimatedContainer(
              curve: Curves.easeInOut,
              duration: Duration(milliseconds: 300),
              height: widget.isMute ? 100 : 100 + (40 * widget.volumeLevel),
              width: widget.isMute ? 100 : 100 + (40 * widget.volumeLevel),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withOpacity(0.6),
              ),
            ),
            Container(
              height: 100,
              width: 100,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: Colors.pink),
              child: Text(
                "M",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class VolumePainter extends CustomPainter {
  final double value;

  VolumePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final radius = value;
    canvas.drawCircle(size.center(Offset.zero), radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
