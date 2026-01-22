# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "cryptography",
# ]
# ///
"""
Secure G-Set Sync Protocol with Cryptographic Authentication

Features:
- Ed25519 signatures for peer discovery
- X25519 key exchange for HTTP encryption
- Challenge-response authentication

Run: uv run protocol_demo.py

Run two instances:
  Terminal 1: python sync_demo.py --port 8001 --name Alice --keyfile alice.key
  Terminal 2: python sync_demo.py --port 8002 --name Bob --keyfile alice.key

Commands: create, update, delete, list, peers, sync <name>, sync all, quit
"""

import argparse
import hashlib
import json
import time
import uuid
import socket
import threading
import base64
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import urlopen, Request
from urllib.parse import urlparse, parse_qs

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
    from cryptography.hazmat.primitives import serialization, hashes
    from cryptography.hazmat.primitives.kdf.hkdf import HKDF
    from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
    from cryptography.exceptions import InvalidSignature, InvalidTag
except ImportError:
    print("Please install cryptography: pip install cryptography")
    exit(1)

# ============================================================================
# CONFIGURATION
# ============================================================================

DISCOVERY_PORT = 37520
BROADCAST_INTERVAL = 5
PEER_TIMEOUT = 15

# ============================================================================
# CRYPTOGRAPHIC IDENTITY
# ============================================================================

class CryptoIdentity:
    """Manages keypairs for identity and encryption"""
    
    def __init__(self, keyfile):
        self.keyfile = keyfile
        self.sign_private_key = None  # Ed25519 for signing
        self.sign_public_key = None
        self.encrypt_private_key = None  # X25519 for encryption
        self.encrypt_public_key = None
        self.user_id = None
        
    def load_or_create(self):
        """Load or create keypairs"""
        try:
            with open(self.keyfile, 'r') as f:
                data = json.load(f)
                
            # Load signing key
            sign_key_data = base64.b64decode(data['sign_private'])
            self.sign_private_key = Ed25519PrivateKey.from_private_bytes(sign_key_data)
            
            # Load encryption key
            encrypt_key_data = base64.b64decode(data['encrypt_private'])
            self.encrypt_private_key = X25519PrivateKey.from_private_bytes(encrypt_key_data)
            
            print(f"🔑 Loaded keypairs from {self.keyfile}")
            
        except FileNotFoundError:
            # Create new keypairs
            self.sign_private_key = Ed25519PrivateKey.generate()
            self.encrypt_private_key = X25519PrivateKey.generate()
            
            # Save to file
            sign_bytes = self.sign_private_key.private_bytes(
                encoding=serialization.Encoding.Raw,
                format=serialization.PrivateFormat.Raw,
                encryption_algorithm=serialization.NoEncryption()
            )
            encrypt_bytes = self.encrypt_private_key.private_bytes(
                encoding=serialization.Encoding.Raw,
                format=serialization.PrivateFormat.Raw,
                encryption_algorithm=serialization.NoEncryption()
            )
            
            data = {
                'sign_private': base64.b64encode(sign_bytes).decode(),
                'encrypt_private': base64.b64encode(encrypt_bytes).decode(),
            }
            
            with open(self.keyfile, 'w') as f:
                json.dump(data, f)
            
            print(f"🔑 Created new keypairs in {self.keyfile}")
        
        self.sign_public_key = self.sign_private_key.public_key()
        self.encrypt_public_key = self.encrypt_private_key.public_key()
        
        # User ID from signing public key
        pub_bytes = self.sign_public_key.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw
        )
        self.user_id = hashlib.sha256(pub_bytes).hexdigest()[:16]
        print(f"👤 User ID: {self.user_id}")
    
    def get_sign_public_key_b64(self):
        """Get signing public key as base64"""
        pub_bytes = self.sign_public_key.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw
        )
        return base64.b64encode(pub_bytes).decode()
    
    def get_encrypt_public_key_b64(self):
        """Get encryption public key as base64"""
        pub_bytes = self.encrypt_public_key.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw
        )
        return base64.b64encode(pub_bytes).decode()
    
    def sign_message(self, message_dict):
        """Sign a message"""
        message_json = json.dumps(message_dict, sort_keys=True)
        signature = self.sign_private_key.sign(message_json.encode())
        return base64.b64encode(signature).decode()
    
    def derive_shared_key(self, peer_encrypt_public_key_b64):
        """Derive shared encryption key with peer"""
        peer_pub_bytes = base64.b64decode(peer_encrypt_public_key_b64)
        peer_public_key = X25519PublicKey.from_public_bytes(peer_pub_bytes)
        
        shared_secret = self.encrypt_private_key.exchange(peer_public_key)
        
        # Derive key using HKDF
        derived_key = HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=None,
            info=b'sync-protocol-v1',
        ).derive(shared_secret)
        
        return derived_key
    
    def encrypt_message(self, plaintext, shared_key):
        """Encrypt message with ChaCha20-Poly1305"""
        cipher = ChaCha20Poly1305(shared_key)
        nonce = os.urandom(12)
        ciphertext = cipher.encrypt(nonce, plaintext.encode(), None)
        
        return {
            'nonce': base64.b64encode(nonce).decode(),
            'ciphertext': base64.b64encode(ciphertext).decode(),
        }
    
    def decrypt_message(self, encrypted_data, shared_key):
        """Decrypt message"""
        cipher = ChaCha20Poly1305(shared_key)
        nonce = base64.b64decode(encrypted_data['nonce'])
        ciphertext = base64.b64decode(encrypted_data['ciphertext'])
        
        plaintext = cipher.decrypt(nonce, ciphertext, None)
        return plaintext.decode()
    
    @staticmethod
    def verify_message(sign_public_key_b64, message_dict, signature_b64):
        """Verify a signed message"""
        try:
            pub_bytes = base64.b64decode(sign_public_key_b64)
            from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
            public_key = Ed25519PublicKey.from_public_bytes(pub_bytes)
            
            message_json = json.dumps(message_dict, sort_keys=True)
            signature = base64.b64decode(signature_b64)
            public_key.verify(signature, message_json.encode())
            return True
        except (InvalidSignature, Exception):
            return False
    
    @staticmethod
    def get_user_id_from_public_key(sign_public_key_b64):
        """Get user ID from signing public key"""
        pub_bytes = base64.b64decode(sign_public_key_b64)
        return hashlib.sha256(pub_bytes).hexdigest()[:16]

# ============================================================================
# G-SET
# ============================================================================

class GSet:
    def __init__(self):
        self.events = {}
    
    def add(self, event):
        event_hash = event['hash']
        if event_hash not in self.events:
            self.events[event_hash] = event
            return True
        return False
    
    def get_hashes(self):
        return set(self.events.keys())
    
    def get_events(self, hashes):
        return [self.events[h] for h in hashes if h in self.events]
    
    def merge(self, other_events):
        added = 0
        for event in other_events:
            if self.add(event):
                added += 1
        return added

# ============================================================================
# EVENT CREATION
# ============================================================================

def create_event(event_type, note_id, content):
    event = {
        'id': str(uuid.uuid4()),
        'type': event_type,
        'noteId': note_id,
        'content': content,
        'timestamp': int(time.time() * 1000),
    }
    hash_input = f"{event['id']}{event['type']}{event['noteId']}{event['timestamp']}{event['content']}"
    event['hash'] = hashlib.sha256(hash_input.encode()).hexdigest()[:16]
    return event

def build_notes_from_events(gset):
    events = sorted(gset.events.values(), key=lambda e: e['timestamp'])
    notes = {}
    for event in events:
        if event['type'] in ('CREATE', 'UPDATE'):
            notes[event['noteId']] = {
                'id': event['noteId'],
                'content': event['content'],
                'timestamp': event['timestamp'],
            }
        elif event['type'] == 'DELETE':
            notes.pop(event['noteId'], None)
    return notes

# ============================================================================
# PEER DISCOVERY
# ============================================================================

class PeerDiscovery:
    def __init__(self, device_id, device_name, identity, http_port):
        self.device_id = device_id
        self.device_name = device_name
        self.identity = identity
        self.http_port = http_port
        self.peers = {}
        self.running = False
        self.sock = None
        
    def start(self):
        self.running = True
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        if hasattr(socket, 'SO_REUSEPORT'):
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        self.sock.bind(('', DISCOVERY_PORT))
        self.sock.settimeout(1.0)
        
        threading.Thread(target=self._broadcast_loop, daemon=True).start()
        threading.Thread(target=self._listen_loop, daemon=True).start()
        
        print(f"🔍 Discovery service started on port {DISCOVERY_PORT}")
    
    def _broadcast_loop(self):
        while self.running:
            try:
                payload = {
                    'deviceId': self.device_id,
                    'deviceName': self.device_name,
                    'httpPort': self.http_port,
                    'timestamp': int(time.time()),
                    'signPublicKey': self.identity.get_sign_public_key_b64(),
                    'encryptPublicKey': self.identity.get_encrypt_public_key_b64(),
                }
                
                signature = self.identity.sign_message(payload)
                message = {'payload': payload, 'signature': signature}
                
                self.sock.sendto(
                    json.dumps(message).encode(),
                    ('<broadcast>', DISCOVERY_PORT)
                )
                
                self._cleanup_stale_peers()
                
            except Exception as e:
                if self.running:
                    print(f"Broadcast error: {e}")
            
            time.sleep(BROADCAST_INTERVAL)
    
    def _listen_loop(self):
        while self.running:
            try:
                data, addr = self.sock.recvfrom(4096)
                message = json.loads(data.decode())
                payload = message['payload']
                signature = message['signature']
                
                # Verify signature
                if not CryptoIdentity.verify_message(
                    payload['signPublicKey'], payload, signature
                ):
                    print(f"⚠️  Invalid signature from {addr[0]}")
                    continue
                
                peer_user_id = CryptoIdentity.get_user_id_from_public_key(
                    payload['signPublicKey']
                )
                
                if payload['deviceId'] == self.device_id:
                    continue
                
                if peer_user_id != self.identity.user_id:
                    continue
                
                device_id = payload['deviceId']
                was_new = device_id not in self.peers
                
                self.peers[device_id] = {
                    'deviceId': device_id,
                    'deviceName': payload['deviceName'],
                    'address': addr[0],
                    'httpPort': payload['httpPort'],
                    'url': f"http://{addr[0]}:{payload['httpPort']}",
                    'signPublicKey': payload['signPublicKey'],
                    'encryptPublicKey': payload['encryptPublicKey'],
                    'lastSeen': time.time(),
                }
                
                if was_new:
                    print(f"\n✨ Discovered peer: {payload['deviceName']} at {addr[0]}:{payload['httpPort']}")
                
            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    print(f"Listen error: {e}")
    
    def _cleanup_stale_peers(self):
        now = time.time()
        stale = [
            device_id for device_id, peer in self.peers.items()
            if now - peer['lastSeen'] > PEER_TIMEOUT
        ]
        for device_id in stale:
            peer = self.peers.pop(device_id)
            print(f"\n❌ Lost peer: {peer['deviceName']}")
    
    def get_peers(self):
        return list(self.peers.values())
    
    def get_peer_by_name(self, name):
        for peer in self.peers.values():
            if peer['deviceName'].lower() == name.lower():
                return peer
        return None
    
    def stop(self):
        self.running = False
        if self.sock:
            self.sock.close()

# ============================================================================
# HTTP SERVER
# ============================================================================

class SyncHandler(BaseHTTPRequestHandler):
    gset = None
    identity = None
    active_challenges = {}  # nonce -> timestamp
    
    def log_message(self, format, *args):
        pass
    
    def do_GET(self):
        parsed = urlparse(self.path)
        
        if parsed.path == '/sync/challenge':
            # Step 1: Provide challenge for authentication
            challenge = base64.b64encode(os.urandom(32)).decode()
            timestamp = time.time()
            self.active_challenges[challenge] = timestamp
            
            # Clean old challenges
            now = time.time()
            expired = [c for c, t in self.active_challenges.items() if now - t > 30]
            for c in expired:
                del self.active_challenges[c]
            
            self._send_json(200, {
                'challenge': challenge,
                'serverEncryptKey': self.identity.get_encrypt_public_key_b64(),
            })
        
        elif parsed.path.startswith('/sync/'):
            # All other endpoints require authentication
            auth_header = self.headers.get('X-Auth-Response')
            peer_encrypt_key = self.headers.get('X-Encrypt-Key')
            
            if not self._verify_auth(auth_header, peer_encrypt_key):
                self._send_json(401, {'error': 'Unauthorized'})
                return
            
            # Derive shared key for encryption
            shared_key = self.identity.derive_shared_key(peer_encrypt_key)
            
            if parsed.path == '/sync/inventory':
                hashes = list(self.gset.get_hashes())
                plaintext = json.dumps({'hashes': hashes})
                encrypted = self.identity.encrypt_message(plaintext, shared_key)
                self._send_json(200, encrypted)
            
            elif parsed.path == '/sync/pull':
                params = parse_qs(parsed.query)
                requested_hashes = params.get('hashes', [''])[0].split(',')
                events = self.gset.get_events(requested_hashes)
                plaintext = json.dumps({'events': events})
                encrypted = self.identity.encrypt_message(plaintext, shared_key)
                self._send_json(200, encrypted)
            
            else:
                self._send_json(404, {'error': 'Not found'})
        
        else:
            self._send_json(404, {'error': 'Not found'})
    
    def do_POST(self):
        auth_header = self.headers.get('X-Auth-Response')
        peer_encrypt_key = self.headers.get('X-Encrypt-Key')
        
        if not self._verify_auth(auth_header, peer_encrypt_key):
            self._send_json(401, {'error': 'Unauthorized'})
            return
        
        shared_key = self.identity.derive_shared_key(peer_encrypt_key)
        
        if self.path == '/sync/push':
            content_length = int(self.headers['Content-Length'])
            body = self.rfile.read(content_length)
            encrypted_data = json.loads(body)
            
            try:
                plaintext = self.identity.decrypt_message(encrypted_data, shared_key)
                data = json.loads(plaintext)
                added = self.gset.merge(data['events'])
                
                response = json.dumps({'added': added})
                encrypted_response = self.identity.encrypt_message(response, shared_key)
                self._send_json(200, encrypted_response)
            except (InvalidTag, Exception) as e:
                self._send_json(400, {'error': 'Decryption failed'})
        else:
            self._send_json(404, {'error': 'Not found'})
    
    def _verify_auth(self, auth_header, peer_encrypt_key):
        if not auth_header or not peer_encrypt_key:
            return False
        
        try:
            auth_data = json.loads(base64.b64decode(auth_header))
            challenge = auth_data['challenge']
            signature = auth_data['signature']
            peer_sign_key = auth_data['signPublicKey']
            
            # Verify challenge exists and not expired
            if challenge not in self.active_challenges:
                return False
            
            timestamp = self.active_challenges[challenge]
            if time.time() - timestamp > 30:
                del self.active_challenges[challenge]
                return False
            
            # Verify signature
            if not CryptoIdentity.verify_message(peer_sign_key, {'challenge': challenge}, signature):
                return False
            
            # Verify peer is same user
            peer_user_id = CryptoIdentity.get_user_id_from_public_key(peer_sign_key)
            if peer_user_id != self.identity.user_id:
                return False
            
            # Remove challenge (one-time use)
            del self.active_challenges[challenge]
            return True
            
        except Exception:
            return False
    
    def _send_json(self, code, data):
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

# ============================================================================
# SYNC CLIENT
# ============================================================================

def sync_with_peer(local_gset, local_identity, peer):
    """Execute secure sync protocol"""
    peer_url = peer['url']
    peer_name = peer['deviceName']
    
    print(f"\n🔄 Syncing with {peer_name} ({peer_url})...")
    
    # Helper: Perform full Challenge-Response for ONE request
    def authenticated_request(endpoint, data=None):
        # 1. Get new challenge
        req = Request(f"{peer_url}/sync/challenge")
        with urlopen(req, timeout=5) as response:
            resp_data = json.loads(response.read())
            challenge = resp_data['challenge']
            server_key = resp_data['serverEncryptKey']

        # 2. Sign challenge
        signature = local_identity.sign_message({'challenge': challenge})
        auth_data = {
            'challenge': challenge,
            'signature': signature,
            'signPublicKey': local_identity.get_sign_public_key_b64(),
        }
        auth_header = base64.b64encode(json.dumps(auth_data).encode()).decode()
        
        # 3. Derive key
        shared_key = local_identity.derive_shared_key(server_key)
        
        headers = {
            'X-Auth-Response': auth_header,
            'X-Encrypt-Key': local_identity.get_encrypt_public_key_b64(),
        }
        
        if data:
            headers['Content-Type'] = 'application/json'
            req = Request(f"{peer_url}{endpoint}", data=data, headers=headers)
        else:
            req = Request(f"{peer_url}{endpoint}", headers=headers)
            
        with urlopen(req, timeout=5) as response:
            return json.loads(response.read()), shared_key

    try:
        # Step 1: Get encrypted inventory
        encrypted_data, shared_key = authenticated_request("/sync/inventory")
        plaintext = local_identity.decrypt_message(encrypted_data, shared_key)
        data = json.loads(plaintext)
        peer_hashes = set(data['hashes'])
        
        local_hashes = local_gset.get_hashes()
        we_need = peer_hashes - local_hashes
        they_need = local_hashes - peer_hashes
        
        print(f"  We need: {len(we_need)} events")
        print(f"  They need: {len(they_need)} events")
        
        # Step 2: Pull events (New Challenge!)
        if we_need:
            hashes_str = ','.join(we_need)
            encrypted_data, shared_key = authenticated_request(f"/sync/pull?hashes={hashes_str}")
            plaintext = local_identity.decrypt_message(encrypted_data, shared_key)
            data = json.loads(plaintext)
            added = local_gset.merge(data['events'])
            print(f"  ✓ Pulled and added {added} events")
        
        # Step 3: Push events (New Challenge!)
        if they_need:
            events = local_gset.get_events(they_need)
            plaintext = json.dumps({'events': events})
            # Note: We need the key first to encrypt, so we actually have to modify auth_request 
            # or do the handshake manually here.
            # Ideally, `authenticated_request` would take a callback for the body to handle this cleanly.
            # For simplicity, let's just do the handshake manually for PUSH:
            
            # 3a. Handshake
            req = Request(f"{peer_url}/sync/challenge")
            with urlopen(req, timeout=5) as r:
                c_data = json.loads(r.read())
            
            # 3b. Sign
            sig = local_identity.sign_message({'challenge': c_data['challenge']})
            auth_h = base64.b64encode(json.dumps({
                'challenge': c_data['challenge'], 'signature': sig, 
                'signPublicKey': local_identity.get_sign_public_key_b64()
            }).encode()).decode()
            
            # 3c. Encrypt & Send
            s_key = local_identity.derive_shared_key(c_data['serverEncryptKey'])
            enc_body = local_identity.encrypt_message(plaintext, s_key)
            
            req = Request(f"{peer_url}/sync/push", data=json.dumps(enc_body).encode(), headers={
                'X-Auth-Response': auth_h,
                'X-Encrypt-Key': local_identity.get_encrypt_public_key_b64(),
                'Content-Type': 'application/json'
            })
            with urlopen(req, timeout=5) as r:
                resp = json.loads(r.read())
                
            print(f"  ✓ Pushed events to peer")

        print("  ✅ Sync complete!\n")
        return True
        
    except Exception as e:
        print(f"  ❌ Sync failed: {e}\n")
        return False

# ============================================================================
# MAIN
# ============================================================================

def run_server(gset, identity, port):
    SyncHandler.gset = gset
    SyncHandler.identity = identity
    server = HTTPServer(('', port), SyncHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server

def main():
    parser = argparse.ArgumentParser(description='Secure G-Set Sync Protocol')
    parser.add_argument('--port', type=int, required=True)
    parser.add_argument('--name', type=str, required=True)
    parser.add_argument('--keyfile', type=str, required=True)
    args = parser.parse_args()
    
    identity = CryptoIdentity(args.keyfile)
    identity.load_or_create()
    
    device_id = str(uuid.uuid4())
    gset = GSet()
    
    server = run_server(gset, identity, args.port)
    discovery = PeerDiscovery(device_id, args.name, identity, args.port)
    discovery.start()
    
    print(f"\n🚀 {args.name} started on http://localhost:{args.port}")
    print(f"📱 Device ID: {device_id[:8]}...")
    print("\nCommands: create <text> | list | peers | sync <name> | sync all | quit\n")
    
    while True:
        try:
            cmd = input(f"{args.name}> ").strip().split(maxsplit=1)
            if not cmd:
                continue
            
            action = cmd[0].lower()
            
            if action == 'create' and len(cmd) > 1:
                note_id = str(uuid.uuid4())[:8]
                event = create_event('CREATE', note_id, cmd[1])
                gset.add(event)
                print(f"✓ Created note {note_id}")
            
            elif action == 'list':
                notes = build_notes_from_events(gset)
                print(f"\n📝 {len(notes)} notes (from {len(gset.events)} events):")
                for note in notes.values():
                    print(f"  [{note['id']}] {note['content']}")
                print()
            
            elif action == 'peers':
                peers = discovery.get_peers()
                print(f"\n👥 {len(peers)} authenticated peers:")
                for peer in peers:
                    age = int(time.time() - peer['lastSeen'])
                    print(f"  • {peer['deviceName']} - {peer['url']} ({age}s ago)")
                print()
            
            elif action == 'sync':
                if len(cmd) > 1:
                    if cmd[1].lower() == 'all':
                        peers = discovery.get_peers()
                        for peer in peers:
                            sync_with_peer(gset, identity, peer)
                    else:
                        peer = discovery.get_peer_by_name(cmd[1])
                        if peer:
                            sync_with_peer(gset, identity, peer)
                        else:
                            print(f"Peer '{cmd[1]}' not found")
            
            elif action == 'quit':
                break
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}")
    
    discovery.stop()
    server.shutdown()

if __name__ == '__main__':
    main()