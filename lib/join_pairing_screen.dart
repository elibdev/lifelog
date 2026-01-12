import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'sync/sync_manager.dart';
import 'sync/peer_discovery.dart';
import 'sync/crypto_identity.dart';
import 'sync/trusted_peers.dart';

enum JoinPairingStatus {
  selecting,
  enteringCode,
  pairing,
  success,
  error,
}

class JoinPairingScreen extends StatefulWidget {
  const JoinPairingScreen({super.key});

  @override
  State<JoinPairingScreen> createState() => _JoinPairingScreenState();
}

class _JoinPairingScreenState extends State<JoinPairingScreen> {
  JoinPairingStatus _status = JoinPairingStatus.selecting;
  String _code = '';
  String _errorMessage = '';
  List<PairingInvitation> _discoveredPeers = [];
  PairingInvitation? _selectedPeer;
  StreamSubscription<PairingInvitation>? _invitationSubscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _invitationSubscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    setState(() {
      _status = JoinPairingStatus.selecting;
      _errorMessage = '';
    });

    _invitationSubscription?.cancel();
    _invitationSubscription = SyncManager.instance.discovery.pairingInvitations.listen(
      (invitation) {
        if (!mounted) return;
        setState(() {
          if (!_discoveredPeers.any((p) => p.deviceId == invitation.deviceId) &&
              invitation.validUntil.isAfter(DateTime.now())) {
            _discoveredPeers.add(invitation);
          }
        });
      },
    );
  }

  void _selectPeer(PairingInvitation invitation) {
    setState(() {
      _selectedPeer = invitation;
      _code = invitation.pairingCode;
      _status = JoinPairingStatus.enteringCode;
    });
  }

  Future<void> _confirmPairing() async {
    if (_code.isEmpty || _code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a 6-digit code';
      });
      return;
    }

    setState(() {
      _status = JoinPairingStatus.pairing;
      _errorMessage = '';
    });

    try {
      PairingInvitation? targetPeer;
      if (_selectedPeer == null) {
        for (final peer in _discoveredPeers) {
          if (peer.pairingCode == _code) {
            targetPeer = peer;
            break;
          }
        }
      } else {
        targetPeer = _selectedPeer;
      }

      if (targetPeer == null) {
        setState(() {
          _status = JoinPairingStatus.error;
          _errorMessage = 'No device found with this code';
        });
        return;
      }

      final peer = targetPeer!;
      final identity = SyncManager.instance.identity;

      final payload = {
        'peerDeviceId': peer.deviceId,
        'peerCode': peer.pairingCode,
        'myCode': _code,
        'peerSignPublicKey': peer.signPublicKey,
        'peerEncryptPublicKey': peer.encryptPublicKey,
      };

      final signature = await identity.signPairingCode(_code, payload);

      final requestData = {
        ...payload,
        'signature': signature,
      };

      final response = await http.post(
        Uri.parse('http://${peer.address}:${peer.httpPort}/sync/pair'),
        headers: {'Content-Type': 'application/json'},
        body: requestData,
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          await _addPeerToTrustedPeers(peer);

          setState(() {
            _status = JoinPairingStatus.success;
          });
        } else {
          setState(() {
            _status = JoinPairingStatus.error;
            _errorMessage = responseData['message'] ?? 'Pairing failed';
          });
        }
      } else if (response.statusCode == 403) {
        setState(() {
          _status = JoinPairingStatus.error;
          _errorMessage = 'Invalid code or code expired';
        });
      } else {
        setState(() {
          _status = JoinPairingStatus.error;
          _errorMessage = 'Pairing failed: ${response.statusCode} ${response.body}';
        });
      }

    } catch (e) {
      setState(() {
        _status = JoinPairingStatus.error;
        _errorMessage = 'Pairing failed: $e';
      });
    }
  }

  Future<void> _addPeerToTrustedPeers(PairingInvitation invitation) async {
    final peerUserId = CryptoIdentity.getUserIdFromPublicKey(invitation.signPublicKey);

    final trustedPeer = TrustedPeer(
      deviceId: invitation.deviceId,
      userId: peerUserId,
      deviceName: invitation.deviceName,
      signPublicKey: invitation.signPublicKey,
      encryptPublicKey: invitation.encryptPublicKey,
      pairedAt: DateTime.now(),
    );

    await TrustedPeers.instance.addTrustedPeer(trustedPeer);
  }

  void _cancelPairing() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join Pairing'),
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
      case JoinPairingStatus.selecting:
        return _buildSelecting();
      case JoinPairingStatus.enteringCode:
        return _buildEnteringCode();
      case JoinPairingStatus.pairing:
        return _buildPairing();
      case JoinPairingStatus.success:
        return _buildSuccess();
      case JoinPairingStatus.error:
        return _buildError();
      default:
        return _buildSelecting();
    }
  }

  Widget _buildSelecting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter pairing code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              TextField(
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, letterSpacing: 8),
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '000000',
                ),
                onChanged: (value) {
                  setState(() {
                    _code = value;
                  });
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nearby devices in pairing mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Expanded(
                child: _discoveredPeers.isEmpty
                    ? Center(
                        child: Text(
                          'No devices found yet\nMake sure both devices are on same network',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _discoveredPeers.length,
                        itemBuilder: (context, index) {
                          final peer = _discoveredPeers[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(Icons.devices),
                              title: Text(peer.deviceName),
                              subtitle: Text('Code: ${peer.pairingCode}'),
                              trailing: Icon(Icons.arrow_forward_ios),
                              onTap: () => _selectPeer(peer),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: _code.length == 6 ? _confirmPairing : null,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, 48),
          ),
          child: Text('Pair with Code'),
        ),
        SizedBox(height: 8),
        OutlinedButton(
          onPressed: _cancelPairing,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, 48),
          ),
          child: Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildEnteringCode() {
    final peer = _selectedPeer!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.devices, size: 60, color: Colors.green),
              SizedBox(height: 16),
              Text(
                'Pairing with ${peer.deviceName}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Enter ${peer.pairingCode} to confirm',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 32),
              Container(
                width: 200,
                child: TextField(
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, letterSpacing: 8),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '000000',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _code = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: _code.length == 6 ? _confirmPairing : null,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, 48),
          ),
          child: Text('Confirm Pairing'),
        ),
        SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _selectedPeer = null;
              _code = '';
              _status = JoinPairingStatus.selecting;
            });
          },
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, 48),
          ),
          child: Text('Back'),
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
                _status = JoinPairingStatus.selecting;
                _code = '';
                _selectedPeer = null;
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
