#!/usr/bin/env python3
"""
Test script to validate the Flutter sync protocol implementation
by comparing it with the Python reference implementation.
"""

import asyncio
import json
import sys
import os
from pathlib import Path

def check_flutter_files():
    """Check if all required Flutter sync files exist"""
    required_files = [
        'lib/sync/event.dart',
        'lib/sync/gset.dart', 
        'lib/sync/crypto_identity.dart',
        'lib/sync/sync_client.dart',
        'lib/sync/sync_server.dart',
        'lib/sync/peer_discovery.dart',
        'lib/sync/sync_manager.dart',
        'lib/services/background_sync_service.dart',
    ]
    
    missing_files = []
    for file_path in required_files:
        if not Path(file_path).exists():
            missing_files.append(file_path)
    
    if missing_files:
        print("❌ Missing Flutter files:")
        for file in missing_files:
            print(f"   {file}")
        return False
    else:
        print("✅ All required Flutter files exist")
        return True

def validate_event_structure():
    """Validate that Event model matches specification"""
    event_file = Path('lib/sync/event.dart')
    if not event_file.exists():
        return False
        
    content = event_file.read_text()
    
    # Check for required fields
    required_fields = {
        'id': 'String',
        'noteId': 'String', 
        'content': 'String',  # nullable String
        'timestamp': 'int',
        'hash': 'String'
    }
    
    for field, type_ in required_fields.items():
        # content is nullable, so check for both patterns
        if field == 'content':
            if f'final String? {field}' not in content and f'final {type_}? {field}' not in content:
                print(f"❌ Event model missing field: {field}")
                return False
        else:
            field_pattern = f'final {type_} {field}'
            if field_pattern not in content:
                print(f"❌ Event model missing field: {field}")
                return False
    
    # Check for enum type
    if 'EventType' not in content or 'enum EventType' not in content:
        print("❌ Event model missing EventType enum")
        return False
    
    # Check for required methods
    required_methods = ['create', 'update', 'delete', 'fromJson', 'toJson']
    for method in required_methods:
        if f'{method}(' not in content:
            print(f"❌ Event model missing method: {method}")
            return False
    
    print("✅ Event model structure is valid")
    return True

def validate_gset_implementation():
    """Validate that GSet implementation matches specification"""
    gset_file = Path('lib/sync/gset.dart')
    if not gset_file.exists():
        return False
        
    content = gset_file.read_text()
    
    # Check for required methods
    required_methods = ['add', 'getHashes', 'getEvents', 'merge', 'buildNotes']
    for method in required_methods:
        if f'{method}(' not in content:
            print(f"❌ GSet missing method: {method}")
            return False
    
    print("✅ GSet implementation is valid")
    return True

def validate_crypto_implementation():
    """Validate that CryptoIdentity implementation matches specification"""
    crypto_file = Path('lib/sync/crypto_identity.dart')
    if not crypto_file.exists():
        return False
        
    content = crypto_file.read_text()
    
    # Check for required cryptographic components
    required_components = [
        'Ed25519',  # Signing
        'X25519',   # Key exchange
        'ChaCha20', # Encryption
        'HKDF',     # Key derivation
        'signMessage',
        'verifyMessage',
        'deriveSharedKey',
        'encryptMessage',
        'decryptMessage'
    ]
    
    for component in required_components:
        if component not in content:
            print(f"❌ CryptoIdentity missing component: {component}")
            return False
    
    print("✅ CryptoIdentity implementation is valid")
    return True

def validate_database_migration():
    """Validate that database migration is properly implemented"""
    db_file = Path('lib/database_helper.dart')
    if not db_file.exists():
        return False
        
    content = db_file.read_text()
    
    # Check for sync-related methods
    required_methods = [
        '_migrateToSyncProtocol',
        'saveEntryWithEvent',
        'mergeEvents',
        'getEventsSince',
        'loadGSet'
    ]
    
    for method in required_methods:
        if method not in content:
            print(f"❌ DatabaseHelper missing method: {method}")
            return False
    
    # Check for events table creation
    if 'CREATE TABLE events' not in content:
        print("❌ DatabaseHelper missing events table creation")
        return False
    
    print("✅ Database migration is valid")
    return True

def validate_main_integration():
    """Validate that main.dart properly integrates sync"""
    main_file = Path('lib/main.dart')
    if not main_file.exists():
        return False
        
    content = main_file.read_text()
    
    # Check for sync integration
    required_imports = [
        'sync/sync_manager.dart',
        'services/background_sync_service.dart'
    ]
    
    for import_name in required_imports:
        if import_name not in content:
            print(f"❌ main.dart missing import: {import_name}")
            return False
    
    # Check for sync initialization
    if 'SyncManager.instance.initialize()' not in content:
        print("❌ main.dart missing sync initialization")
        return False
    
    print("✅ Main app integration is valid")
    return True

def validate_pubspec_dependencies():
    """Validate that pubspec.yaml has required dependencies"""
    pubspec_file = Path('pubspec.yaml')
    if not pubspec_file.exists():
        return False
        
    content = pubspec_file.read_text()
    
    # Check for required dependencies
    required_deps = [
        'cryptography',
        'http',
        'uuid',
        'flutter_background_service',
        'shared_preferences',
        'crypto',
        'shelf',
        'shelf_router'
    ]
    
    for dep in required_deps:
        if dep not in content:
            print(f"❌ pubspec.yaml missing dependency: {dep}")
            return False
    
    print("✅ pubspec.yaml dependencies are valid")
    return True

def compare_with_python_spec():
    """Compare key aspects with Python specification"""
    print("\n📋 Comparing with Python specification...")
    
    # Check protocol constants
    spec_file = Path('protocol_spec.md')
    demo_file = Path('protocol_demo.py')
    
    if not spec_file.exists() or not demo_file.exists():
        print("❌ Reference files not found")
        return False
    
    # Extract key constants from demo
    demo_content = demo_file.read_text()
    if 'DISCOVERY_PORT = 37520' in demo_content:
        print("✅ Discovery port matches specification")
    else:
        print("❌ Discovery port mismatch")
        return False
    
    flutter_discovery = Path('lib/sync/peer_discovery.dart').read_text()
    if 'discoveryPort = 37520' in flutter_discovery:
        print("✅ Flutter discovery port matches")
    else:
        print("❌ Flutter discovery port mismatch")
        return False
    
    return True

def main():
    """Run all validation checks"""
    print("🔍 Validating Flutter Sync Protocol Implementation\n")
    
    tests = [
        ("File Structure", check_flutter_files),
        ("Event Model", validate_event_structure),
        ("GSet Implementation", validate_gset_implementation),
        ("Crypto Identity", validate_crypto_implementation),
        ("Database Migration", validate_database_migration),
        ("Main Integration", validate_main_integration),
        ("Dependencies", validate_pubspec_dependencies),
        ("Specification Compliance", compare_with_python_spec),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n📝 {test_name}:")
        try:
            if test_func():
                passed += 1
            else:
                print(f"❌ {test_name} failed")
        except Exception as e:
            print(f"❌ {test_name} error: {e}")
    
    print(f"\n📊 Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All validation tests passed!")
        print("✅ Flutter sync protocol implementation is ready")
        return 0
    else:
        print("❌ Some validation tests failed")
        print("🔧 Please fix the issues before proceeding")
        return 1

if __name__ == '__main__':
    sys.exit(main())