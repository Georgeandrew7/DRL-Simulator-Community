#!/usr/bin/env python3
"""
Certificate generator for DRL Mock Backend Server
Works on Windows without OpenSSL using the 'cryptography' library
"""

import os
import platform
import subprocess


def generate_self_signed_cert():
    """Generate self-signed certificate for HTTPS - works on Windows without OpenSSL"""
    
    # Use temp directory appropriate for the OS
    if platform.system() == 'Windows':
        temp_dir = os.environ.get('TEMP', 'C:\\Temp')
    else:
        temp_dir = '/tmp'
    
    cert_path = os.path.join(temp_dir, 'drl_mock_cert.pem')
    key_path = os.path.join(temp_dir, 'drl_mock_key.pem')
    
    if os.path.exists(cert_path) and os.path.exists(key_path):
        return cert_path, key_path
    
    print("Generating self-signed certificate for HTTPS...")
    
    # Try using cryptography library first (pure Python, works everywhere)
    try:
        from cryptography import x509
        from cryptography.x509.oid import NameOID
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import rsa
        from datetime import datetime, timedelta
        
        # Generate private key
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        
        # Generate certificate
        subject = issuer = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, "api.drlgame.com"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "DRL Mock Server"),
        ])
        
        cert = (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(issuer)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(datetime.utcnow())
            .not_valid_after(datetime.utcnow() + timedelta(days=365))
            .add_extension(
                x509.SubjectAlternativeName([x509.DNSName("api.drlgame.com")]),
                critical=False,
            )
            .sign(key, hashes.SHA256())
        )
        
        # Write key
        with open(key_path, "wb") as f:
            f.write(key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption()
            ))
        
        # Write certificate
        with open(cert_path, "wb") as f:
            f.write(cert.public_bytes(serialization.Encoding.PEM))
        
        print(f"  Certificate: {cert_path}")
        print(f"  Key: {key_path}")
        return cert_path, key_path
        
    except ImportError:
        print("  Note: 'cryptography' package not installed, trying openssl...")
    
    # Fallback to openssl command (works on Linux/Mac)
    cmd = [
        'openssl', 'req', '-x509', '-newkey', 'rsa:2048',
        '-keyout', key_path, '-out', cert_path,
        '-days', '365', '-nodes',
        '-subj', '/CN=api.drlgame.com/O=DRL Mock Server'
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True)
        print(f"  Certificate: {cert_path}")
        print(f"  Key: {key_path}")
        return cert_path, key_path
    except Exception as e:
        print(f"Warning: Could not generate certificate: {e}")
        print("  HTTPS will not work. Install 'cryptography' package:")
        print("    pip install cryptography")
        return None, None


if __name__ == '__main__':
    cert, key = generate_self_signed_cert()
    if cert and key:
        print("Certificate generated successfully!")
    else:
        print("Failed to generate certificate")
