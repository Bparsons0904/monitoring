#!/usr/bin/env python3
"""
Temperature and humidity collector for Adafruit SHT4x Trinkey
Communicates over serial interface to read actual sensor data
"""

import os
import sys
import time
import serial
from pathlib import Path

OUTPUT_FILE = "/home/server/monitoring/textfiles/temp_humidity.prom"

def find_trinkey_device():
    """Find the Adafruit Trinkey device path"""
    # Check for ttyACM devices first (most common for Trinkey)
    for i in range(10):  # Check ttyACM0 through ttyACM9
        device_path = f"/dev/ttyACM{i}"
        if os.path.exists(device_path):
            try:
                # Try to verify this is accessible
                with serial.Serial(device_path, 115200, timeout=1) as ser:
                    return device_path
            except PermissionError:
                print(f"Found device {device_path} but permission denied.")
                print("Run: sudo usermod -a -G dialout $USER")
                print("Then logout and login again.")
                return None
            except Exception as e:
                print(f"Device {device_path} exists but cannot access: {e}")
                continue
    
    # Check for ttyUSB devices as fallback
    for i in range(10):
        device_path = f"/dev/ttyUSB{i}"
        if os.path.exists(device_path):
            try:
                with serial.Serial(device_path, 115200, timeout=1) as ser:
                    return device_path
            except PermissionError:
                print(f"Found device {device_path} but permission denied.")
                print("Run: sudo usermod -a -G dialout $USER")
                print("Then logout and login again.")
                return None
            except Exception as e:
                print(f"Device {device_path} exists but cannot access: {e}")
                continue
    
    return None

def read_sensor_data(device_path):
    """Read actual sensor data from SHT4x Trinkey"""
    try:
        with serial.Serial(device_path, 115200, timeout=3) as ser:
            print(f"Connected to {device_path}")
            
            # The device continuously outputs data, just read a line
            for attempt in range(5):  # Try up to 5 times
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                print(f"Received: '{line}'")
                
                if line:
                    result = parse_sensor_response(line)
                    if result[0] is not None:
                        return result
            
            print("No valid sensor data received after 5 attempts")
                    
    except Exception as e:
        print(f"Error reading sensor: {e}")
        return None, None
    
    return None, None

def parse_sensor_response(response):
    """Parse sensor response in CSV format: timestamp, temperature, humidity, extra"""
    try:
        if ',' in response:
            parts = [p.strip() for p in response.split(',')]
            if len(parts) >= 3:
                # Format appears to be: timestamp, temperature, humidity, extra
                temperature = float(parts[1])
                humidity = float(parts[2])
                
                # Basic sanity check
                if -40 <= temperature <= 85 and 0 <= humidity <= 100:
                    return temperature, humidity
                
    except (ValueError, IndexError):
        pass
    
    return None, None

def write_metrics(temperature, humidity):
    """Write metrics in Prometheus format"""
    # Ensure output directory exists
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    
    # Write to temporary file first
    tmp_file = OUTPUT_FILE + ".tmp"
    timestamp = int(time.time())
    
    with open(tmp_file, 'w') as f:
        f.write(f"""# HELP room_temperature_celsius Room temperature in Celsius
# TYPE room_temperature_celsius gauge
room_temperature_celsius{{sensor="sht4x",location="server_room"}} {temperature:.2f}

# HELP room_humidity_percent Room humidity percentage  
# TYPE room_humidity_percent gauge
room_humidity_percent{{sensor="sht4x",location="server_room"}} {humidity:.2f}

# HELP temp_humidity_last_updated_timestamp Last update timestamp for temperature/humidity metrics
# TYPE temp_humidity_last_updated_timestamp gauge
temp_humidity_last_updated_timestamp {timestamp}
""")
    
    # Atomic move to final location
    os.rename(tmp_file, OUTPUT_FILE)

def main():
    """Main function"""
    device = find_trinkey_device()
    
    if device:
        print(f"Found device: {device}")
        temperature, humidity = read_sensor_data(device)
        
        if temperature is not None and humidity is not None:
            print(f"Temperature: {temperature:.2f}°C, Humidity: {humidity:.2f}%")
            write_metrics(temperature, humidity)
            print(f"Metrics written to {OUTPUT_FILE}")
        else:
            print("Failed to read sensor data - no metrics written")
            # Remove existing metrics file if sensor can't be read
            if os.path.exists(OUTPUT_FILE):
                os.remove(OUTPUT_FILE)
                print(f"Removed stale metrics file: {OUTPUT_FILE}")
    else:
        print("No sensor device found - no metrics written")
        # Remove existing metrics file if no device found
        if os.path.exists(OUTPUT_FILE):
            os.remove(OUTPUT_FILE)
            print(f"Removed stale metrics file: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()