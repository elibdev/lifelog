import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:shared_preferences/shared_preferences.dart';

class CryptoIdentity {
  late final KeyPair _signKeyPair;
  late final KeyPair _encryptKeyPair;
  late final String _userId;
  
  static const String _signKeyPref = 'sync_sign_private_key';
  static const String _encryptKeyPref = 'sync_encrypt_private_key';
  static const String _userIdPref = 'sync_user_id';

  CryptoIdentity._();

  static Future<CryptoIdentity> loadOrCreate() async {
    final identity = CryptoIdentity._();
    await identity._loadOrCreateKeys();
    return identity;
  }

  Future<void> _loadOrCreateKeys() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Try to load existing keys
    final signKeyBytesBase64 = prefs.getString(_signKeyPref);
    final encryptKeyBytesBase64 = prefs.getString(_encryptKeyPref);
    
    if (signKeyBytesBase64 != null && encryptKeyBytesBase64 != null) {
      // Load existing keys
      final signKeyBytes = base64.decode(signKeyBytesBase64!);
      final encryptKeyBytes = base64.decode(encryptKeyBytesBase64!);
      
      _signKeyPair = await Ed25519().newKeyPairFromSeed(signKeyBytes);
      _encryptKeyPair = await X25519().newKeyPairFromSeed(encryptKeyBytes);
      
      print('🔑 Loaded existing cryptographic keys');
    } else {
      // Generate new keys
      final signKeyPair = await Ed25519().newKeyPair();
      final encryptKeyPair = await X25519().newKeyPair();
      
      _signKeyPair = signKeyPair;
      _encryptKeyPair = encryptKeyPair;
      
      // Save keys
      final signKeyData = await signKeyPair.extract();
      final signSeed = signKeyData.bytes;
      final encryptKeyData = await encryptKeyPair.extract();
      final encryptSeed = encryptKeyData.bytes;
      
      await prefs.setString(_signKeyPref, base64.encode(signSeed));
      await prefs.setString(_encryptKeyPref, base64.encode(encryptSeed));
      
      print('🔑 Generated new cryptographic keys');
    }
    
    // Generate user ID from signing public key
    _userId = await _generateUserId();
    print('👤 User ID: $_userId');
  }

  Future<String> _generateUserId() async {
    final pubKey = await _signKeyPair.extractPublicKey();
    final pubKeyBytes = (pubKey as SimplePublicKey).bytes;
    final digest = crypto.sha256.convert(pubKeyBytes);
    return digest.toString().substring(0, 16);
  }

  Future<String> getSignPublicKeyB64() async {
    final pubKey = await _signKeyPair.extractPublicKey();
    final pubKeyBytes = (pubKey as SimplePublicKey).bytes;
    return base64.encode(pubKeyBytes);
  }

  Future<String> getEncryptPublicKeyB64() async {
    final pubKey = await _encryptKeyPair.extractPublicKey();
    final pubKeyBytes = (pubKey as SimplePublicKey).bytes;
    return base64.encode(pubKeyBytes);
  }

  Future<String> signMessage(Map<String, dynamic> message) async {
    final messageJson = json.encode(message);
    final messageBytes = utf8.encode(messageJson);

    final signature = await Ed25519().sign(
      messageBytes,
      keyPair: _signKeyPair,
    );
    return base64.encode(signature.bytes);
  }

  static Future<bool> verifyMessage(
    String signPublicKeyB64,
    Map<String, dynamic> message,
    String signatureB64,
  ) async {
    try {
      final pubKeyBytes = base64.decode(signPublicKeyB64);
      final publicKey = SimplePublicKey(pubKeyBytes, type: KeyPairType.ed25519);

      final messageJson = json.encode(message);
      final messageBytes = utf8.encode(messageJson);

      final signatureBytes = base64.decode(signatureB64);

      return await Ed25519().verify(
        messageBytes,
        signature: Signature(signatureBytes, publicKey: publicKey),
      );
    } catch (e) {
      print('Signature verification failed: $e');
      return false;
    }
  }

  Future<Uint8List> deriveSharedKey(String peerEncryptPublicKeyB64) async {
    try {
      final peerPubKeyBytes = base64.decode(peerEncryptPublicKeyB64);
      final peerPublicKey = SimplePublicKey(peerPubKeyBytes, type: KeyPairType.x25519);

      // Perform key exchange
      final sharedSecret = await X25519().sharedSecretKey(
        keyPair: _encryptKeyPair,
        remotePublicKey: peerPublicKey,
      );
      
      // Derive key using HKDF-SHA256
      final hkdf = Hkdf(
        hmac: Hmac.sha256(),
        outputLength: 32,
      );

      final sharedSecretBytes = await sharedSecret.extractBytes();
      final derivedKey = await hkdf.deriveKey(
        secretKey: SecretKeyData(sharedSecretBytes),
        info: utf8.encode('sync-protocol-v1'),
      );

      return Uint8List.fromList(await derivedKey.extractBytes());
    } catch (e) {
      print('Key derivation failed: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> encryptMessage(
    String plaintext,
    Uint8List sharedKey,
  ) async {
    try {
      final algorithm = Chacha20.poly1305Aead();
      
      // Generate random nonce
      final random = Random.secure();
      final nonce = Uint8List(12);
      for (int i = 0; i < 12; i++) {
        nonce[i] = random.nextInt(256);
      }
      
      // Encrypt message
      final plaintextBytes = utf8.encode(plaintext);
      final secretBox = await algorithm.encrypt(
        plaintextBytes,
        secretKey: SecretKeyData(sharedKey),
        nonce: nonce,
      );

      return {
        'nonce': base64.encode(nonce),
        'ciphertext': base64.encode(secretBox.cipherText),
        'mac': base64.encode(secretBox.mac.bytes),
      };
    } catch (e) {
      print('Encryption failed: $e');
      rethrow;
    }
  }

  Future<String> decryptMessage(
    Map<String, String> encryptedData,
    Uint8List sharedKey,
  ) async {
    try {
      final algorithm = Chacha20.poly1305Aead();

      final nonce = base64.decode(encryptedData['nonce']!);
      final ciphertext = base64.decode(encryptedData['ciphertext']!);
      final macBytes = base64.decode(encryptedData['mac']!);

      // Decrypt message
      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(macBytes));
      final plaintextBytes = await algorithm.decrypt(
        secretBox,
        secretKey: SecretKeyData(sharedKey),
      );

      return utf8.decode(plaintextBytes);
    } catch (e) {
      print('Decryption failed: $e');
      rethrow;
    }
  }

  static String getUserIdFromPublicKey(String signPublicKeyB64) {
    try {
      final pubKeyBytes = base64.decode(signPublicKeyB64);
      final digest = crypto.sha256.convert(pubKeyBytes);
      return digest.toString().substring(0, 16);
    } catch (e) {
      print('Failed to get user ID from public key: $e');
      return '';
    }
  }

  static String generatePairingCode() {
    final random = Random.secure();
    final code = List.generate(6, (_) => random.nextInt(10)).join();
    return code;
  }

  Future<String> signPairingCode(String code, Map<String, dynamic> payload) async {
    final payloadWithCode = {...payload, 'pairingCode': code};
    final messageJson = json.encode(payloadWithCode);
    final messageBytes = utf8.encode(messageJson);

    final signature = await Ed25519().sign(
      messageBytes,
      keyPair: _signKeyPair,
    );
    return base64.encode(signature.bytes);
  }

  static Future<bool> verifyPairingCode(
    String signPublicKeyB64,
    String code,
    Map<String, dynamic> payload,
    String signatureB64,
  ) async {
    try {
      final pubKeyBytes = base64.decode(signPublicKeyB64);
      final publicKey = SimplePublicKey(pubKeyBytes, type: KeyPairType.ed25519);

      final payloadWithCode = {...payload, 'pairingCode': code};
      final messageJson = json.encode(payloadWithCode);
      final messageBytes = utf8.encode(messageJson);

      final signatureBytes = base64.decode(signatureB64);

      return await Ed25519().verify(
        messageBytes,
        signature: Signature(signatureBytes, publicKey: publicKey),
      );
    } catch (e) {
      print('Pairing code verification failed: $e');
      return false;
    }
  }

  Future<void> clearKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_signKeyPref);
    await prefs.remove(_encryptKeyPref);
    await prefs.remove(_userIdPref);
    print('🔑 Cleared all cryptographic keys');
  }

  String get userId => _userId;
}