import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'sync/sync_manager.dart';
import 'sync/crypto_identity.dart';

enum StartPairingStatus {
  waiting,
  pairing,
  success,
  error,
}

class StartPairingScreen extends StatefulWidget {
  const StartPairingScreen({super.key});

  @override
  State<StartPairingScreen> createState() => _StartPairingScreenState();
}

class _StartPairingScreenState extends State<StartPairingScreen> {
  StartPairingStatus _status = StartPairingStatus.waiting;
  String _myCode = '';
  String _errorMessage = '';
  Timer? _countdownTimer;
  int _secondsRemaining = 30;
  String? _previousCode;

  @override
  void initState() {
    super.initState();
    _startPairing();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stopPairingMode();
    super.dispose();
  }

  Future<void> _startPairing() async {
    setState(() {
      _status = StartPairingStatus.waiting;
      _errorMessage = '';
      _secondsRemaining = 30;
    });

    try {
      await SyncManager.instance.discovery.startPairingMode();
      await _generateNewCode();
      _startCountdown();

    } catch (e) {
      setState(() {
        _status = StartPairingStatus.error;
        _errorMessage = 'Failed to start pairing: $e';
      });
    }
  }

  Future<void> _generateNewCode() async {
    final newCode = CryptoIdentity.generatePairingCode();

    // Update pairing code in peer_discovery (this manages broadcasting)
    SyncManager.instance.discovery.updatePairingCode(newCode);

    // Get previous code for display
    final previous = _previousCode;
    setState(() {
      _previousCode = _myCode;
      _myCode = newCode;
    });

    _secondsRemaining = 30;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        _secondsRemaining--;
      });

      // Auto-rotate code when countdown reaches 0
      if (_secondsRemaining <= 0) {
        _manualRotateCode();
      }
    });
  }

  void _manualRotateCode() {
    _generateNewCode();
  }

  Future<void> _stopPairingMode() async {
    await SyncManager.instance.discovery.stopPairingMode();
  }

  Future<void> _cancelPairing() async {
    await _stopPairingMode();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Start Pairing'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_status) {
      case StartPairingStatus.waiting:
        return _buildWaiting();
      case StartPairingStatus.pairing:
        return _buildPairing();
      case StartPairingStatus.success:
        return _buildSuccess();
      case StartPairingStatus.error:
        return _buildError();
      default:
        return _buildWaiting();
    }
  }

  Widget _buildWaiting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_2, size: 100, color: Colors.blue),
              SizedBox(height: 24),
              Text(
                'Your Pairing Code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _myCode,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Enter this code on your other device',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Code expires in $_secondsRemaining seconds',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              SizedBox(height: 32),
              if (_previousCode != null && _previousCode!.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Previous code ',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                    Text(
                      _previousCode!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '(valid for 5 more seconds)',
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ],
              SizedBox(height: 32),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Waiting for other device...',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: _manualRotateCode,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, 48),
          ),
          child: Text('Regenerate Code'),
        ),
        SizedBox(height: 8),
        ElevatedButton(
          onPressed: _cancelPairing,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, 48),
          ),
          child: Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildPairing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Pairing...'),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.green),
          SizedBox(height: 16),
          Text(
            'Pairing Successful!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Your devices are now paired and will sync automatically'),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(200, 48),
            ),
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 80, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Pairing Failed',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _status = StartPairingStatus.waiting;
              });
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(200, 48),
            ),
            child: Text('Retry'),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(200, 48),
            ),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
