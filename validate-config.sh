#!/bin/bash
# Validation script for nvmlfan configuration
# This simulates what nvmlfan would do without actually changing fan speeds

set -e

CONFIG_FILE="${1:-config-test-conservative.yaml}"
NVMLFAN="./nvmlfan"

echo "==================================="
echo "nvmlfan Configuration Validator"
echo "==================================="
echo ""

# Check if nvmlfan binary exists
if [ ! -f "$NVMLFAN" ]; then
    echo "ERROR: nvmlfan binary not found. Run 'go build nvmlfan.go' first."
    exit 1
fi

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file '$CONFIG_FILE' not found."
    exit 1
fi

echo "✓ Binary found: $NVMLFAN"
echo "✓ Config found: $CONFIG_FILE"
echo ""

# List GPUs
echo "==================================="
echo "Step 1: GPU Detection (READ-ONLY)"
echo "==================================="
sudo "$NVMLFAN" --list
echo ""

# Parse config and show what would happen
echo "==================================="
echo "Step 2: Configuration Analysis"
echo "==================================="
echo ""
echo "Configuration file: $CONFIG_FILE"
echo ""
cat "$CONFIG_FILE"
echo ""

# Show current state
echo "==================================="
echo "Step 3: Current System State"
echo "==================================="
nvidia-smi --query-gpu=index,name,temperature.gpu,fan.speed --format=csv,noheader,nounits | while IFS=',' read -r idx name temp fan; do
    echo "GPU $idx: $name"
    echo "  Current Temp: ${temp}°C"
    echo "  Current Fan:  ${fan}%"
    echo ""
done

echo "==================================="
echo "Step 4: Safety Checks"
echo "==================================="
echo ""

# Basic validation
if grep -q "foreground: true" "$CONFIG_FILE"; then
    echo "✓ Foreground mode enabled (safe for testing)"
else
    echo "⚠ WARNING: Foreground mode not enabled"
fi

if grep -q "level: debug" "$CONFIG_FILE"; then
    echo "✓ Debug logging enabled (good for testing)"
else
    echo "⚠ INFO: Debug logging not enabled"
fi

# Check if period is reasonable
PERIOD=$(grep "period:" "$CONFIG_FILE" | awk '{print $2}')
if [ -n "$PERIOD" ] && [ "$PERIOD" -ge 1 ] && [ "$PERIOD" -le 10 ]; then
    echo "✓ Update period: ${PERIOD}s (reasonable)"
else
    echo "⚠ WARNING: Update period may be too fast or not set"
fi

echo ""
echo "==================================="
echo "Step 5: Test Command"
echo "==================================="
echo ""
echo "To test with this configuration, run:"
echo ""
echo "  sudo $NVMLFAN --foreground --config $CONFIG_FILE"
echo ""
echo "Press Ctrl+C to stop (will automatically restore default fan control)"
echo ""
echo "To restore default fan control manually at any time:"
echo ""
echo "  sudo $NVMLFAN --restore"
echo ""
echo "==================================="
echo "Ready to test!"
echo "==================================="
