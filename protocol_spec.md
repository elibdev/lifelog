# Secure G-Set Sync Protocol Specification

**Version:** 1.0
**Status:** Experimental
**Transport:** UDP (Discovery), HTTP (Sync)

## 1. Overview

A decentralized, leaderless protocol for synchronizing Grow-Only Sets (G-Sets) between peers. It provides authenticity, confidentiality, and replay protection without a central authority.

## 2. Cryptography

| Component | Algorithm | Purpose |
| --- | --- | --- |
| **Identity** | Ed25519 | Peer identification and message signing. |
| **Key Exchange** | X25519 | Ephemeral key agreement for session encryption. |
| **KDF** | HKDF-SHA256 | Deriving shared symmetric keys from X25519 secrets. |
| **Encryption** | ChaCha20-Poly1305 | Authenticated encryption of sync payloads. |
| **Hashing** | SHA-256 | Event content addressing and identifying. |

## 3. Data Model

The core data structure is an append-only set of immutable events.

### 3.1 Event Structure

Every item in the store is an "Event" object.

```json
{
  "id": "uuid-v4-string",
  "type": "CREATE | UPDATE | DELETE",
  "noteId": "uuid-v4-string",
  "content": "string",
  "timestamp": 1678886400000,
  "hash": "sha256-hex-digest"
}

```

* **Hash Calculation:** `SHA256(id + type + noteId + timestamp + content)` (first 16 chars).
* **Conflict Resolution:** Last-Write-Wins (LWW) based on `timestamp` for display; all events are retained in the G-Set.

## 4. Discovery Protocol

Peers announce their presence via UDP Broadcast.

* **Port:** `37520`
* **Interval:** ~5 seconds
* **Transport:** UDP Broadcast (`255.255.255.255`)

### 4.1 Packet Format

The payload is wrapped in a signed envelope.

```json
{
  "payload": {
    "deviceId": "uuid",
    "deviceName": "Alice's Laptop",
    "httpPort": 8001,
    "timestamp": 1678886400,
    "signPublicKey": "base64-ed25519-pub",
    "encryptPublicKey": "base64-x25519-pub"
  },
  "signature": "base64-ed25519-sig"
}

```

* **Validation:** Receivers MUST verify the Ed25519 signature against `signPublicKey`.
* **Replay Protection:** Receivers SHOULD discard packets with timestamps >30s old

## 5. Sync Protocol

Synchronization occurs over HTTP. Every HTTP request requires a fresh cryptographic handshake (stateless authentication).

### 5.1 Authentication Flow (Per Request)

1. **Client** requests a challenge: `GET /sync/challenge`
2. **Server** responds:
```json
{
  "challenge": "base64-random-32-bytes",
  "serverEncryptKey": "base64-x25519-pub"
}

```


*Server stores challenge with 30s expiration.*
3. **Client** signs challenge and derives encryption key:
* `Signature = Ed25519_Sign(ClientPriv, json({challenge}))`
* `SharedKey = HKDF(X25519(ClientPriv, ServerPub))`


4. **Client** sends actual request (Inventory/Push/Pull) with headers:
* `X-Auth-Response`: `base64(json({ "challenge": "...", "signature": "...", "signPublicKey": "..." }))`
* `X-Encrypt-Key`: `base64-client-x25519-pub`


5. **Server** verifies:
* Challenge exists and is valid.
* Signature matches `signPublicKey`.
* *Server deletes challenge immediately (preventing replay).*



### 5.2 Endpoints

All payloads below (request bodies and response bodies) are encrypted using ChaCha20-Poly1305 with the derived `SharedKey`.

#### `GET /sync/inventory`

Retrieves all event hashes known to the peer.

* **Response (Decrypted):** `{"hashes": ["hash1", "hash2", ...]}`

#### `GET /sync/pull?hashes=h1,h2`

Retrieves full event objects for specific hashes.

* **Response (Decrypted):** `{"events": [{...}, {...}]}`

#### `POST /sync/push`

Sends new events to the peer.

* **Request Body (Decrypted):** `{"events": [{...}, {...}]}`
* **Response (Decrypted):** `{"added": 5}`

### 5.3 Sync Algorithm

1. **Inventory:** Client fetches peer's hash list.
2. **Diff:**
* `MissingLocal = PeerHashes - LocalHashes`
* `MissingRemote = LocalHashes - PeerHashes`


3. **Pull:** Client requests full events for `MissingLocal`.
4. **Push:** Client sends full events for `MissingRemote`.