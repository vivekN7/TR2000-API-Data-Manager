#!/usr/bin/env python3
"""
Extract RPM files without rpm2cpio
"""
import os
import sys
import gzip
import subprocess

def extract_rpm(rpm_file):
    """Extract RPM using basic tools"""
    print(f"Extracting {rpm_file}...")
    
    # RPMs are cpio archives compressed with gzip
    # Try to extract using different methods
    
    # Method 1: Use 7z if available
    try:
        result = subprocess.run(['7z', 'x', '-y', rpm_file], capture_output=True)
        if result.returncode == 0:
            print("Extracted with 7z")
            return True
    except:
        pass
    
    # Method 2: Manual extraction
    # RPMs have a header followed by a cpio.gz archive
    with open(rpm_file, 'rb') as f:
        data = f.read()
        
    # Find the gzip magic bytes (1f 8b)
    gzip_start = data.find(b'\x1f\x8b')
    if gzip_start > 0:
        print(f"Found gzip data at offset {gzip_start}")
        
        # Write the gzip portion
        gz_file = rpm_file + '.cpio.gz'
        with open(gz_file, 'wb') as f:
            f.write(data[gzip_start:])
        
        # Extract gzip
        os.system(f'gunzip -f {gz_file}')
        
        # Now we have a cpio file
        cpio_file = rpm_file + '.cpio'
        if os.path.exists(cpio_file):
            print(f"Created {cpio_file}")
            # Try to extract with cpio or manually parse
            return True
    
    return False

if __name__ == "__main__":
    for rpm in ['oracle-instantclient-basic-21.14.0.0.0-1.el8.x86_64.rpm',
                'oracle-instantclient-tools-21.14.0.0.0-1.el8.x86_64.rpm']:
        if os.path.exists(rpm):
            extract_rpm(rpm)