# Safe Testing Guide for nvmlfan

## Your System Status
- **GPU 0**: RTX 3090, currently 56°C, fans at 58% (2 fans)
- **GPU 1**: RTX 3090, currently 70°C, fans at 83-84% (2 fans)
- **Fan Range**: 30-100% for both cards
- **Max Safe Temp**: 93°C

## Safe Testing Steps

### Step 1: Read-Only Testing (SAFE - No Changes)
```bash
# List GPU information (completely safe, read-only)
sudo ./nvmlfan --list
```
✅ **Already completed** - This shows your GPUs are detected correctly.

### Step 2: Create Test Configuration
```bash
# Copy the example config
sudo cp config-example.yaml /usr/local/etc/nvmlfan-test.yaml
sudo chmod 644 /usr/local/etc/nvmlfan-test.yaml
```

Edit the test config with conservative, safe values:
```yaml
foreground: true
logging:
  level: debug
  type: stdout
period: 5  # Check every 5 seconds

cards:
  0:
    mode: curve
    curve:
      # Conservative curve - keeps fans high
      - [ 40, 40 ]  # Below 40°C: 40% fan
      - [ 50, 50 ]  # At 50°C: 50% fan
      - [ 60, 60 ]  # At 60°C: 60% fan
      - [ 70, 80 ]  # At 70°C: 80% fan
      - [ 80, 100]  # At 80°C: 100% fan
  1:
    mode: curve
    curve:
      - [ 40, 40 ]
      - [ 50, 50 ]
      - [ 60, 60 ]
      - [ 70, 80 ]
      - [ 80, 100]
```

### Step 3: Foreground Test (SAFE - Easy to Stop)
```bash
# Run in foreground with debug logging
# This will NOT daemonize - you can see everything and Ctrl+C to stop
sudo ./nvmlfan --foreground --config /usr/local/etc/nvmlfan-test.yaml
```

**What to watch for:**
- Temperature readings
- Fan speed changes
- "Setting new speed" debug messages
- Any error messages

**To stop safely:** Press `Ctrl+C` - it will automatically restore default fan control

### Step 4: Test Fan Restore (SAFETY NET)
```bash
# This command restores all GPUs to automatic fan control
# Use this if anything goes wrong
sudo ./nvmlfan --restore
```

### Step 5: Short Duration Test
Run the foreground test for 5-10 minutes while monitoring:
```bash
# Terminal 1: Run nvmlfan
sudo ./nvmlfan --foreground --config /usr/local/etc/nvmlfan-test.yaml

# Terminal 2: Monitor temperatures
watch -n 1 nvidia-smi
```

## Safety Features Built Into nvmlfan

1. **Automatic Restore**: When you stop nvmlfan (Ctrl+C or SIGTERM), it automatically restores default fan control
2. **Clamping**: Fan speeds are automatically limited to GPU's safe range (30-100% for your cards)
3. **Temperature Limits**: Temperatures above GPU max (93°C) are automatically handled
4. **Foreground Mode**: Run without daemonizing for easy testing and monitoring

## Conservative vs Aggressive Configurations

### Conservative (Recommended for Testing)
- Higher fan speeds at lower temperatures
- Prevents thermal issues
- May be noisier
- **Use this first**

### Balanced (After Testing)
```yaml
cards:
  0:
    mode: curve
    curve:
      - [ 50, 30 ]  # Minimum fan speed until 50°C
      - [ 60, 40 ]
      - [ 70, 60 ]
      - [ 80, 90 ]
```

### Target Mode (Advanced - Requires Tuning)
```yaml
cards:
  0:
    mode: target
    target: 65      # Try to maintain 65°C
    pid: [ 20, 0.1, 0 ]  # May need tuning for your system
```
⚠️ **Warning**: PID mode requires tuning. Start with curve mode.

## Recommended Testing Timeline

1. **Day 1**: Foreground testing (1-2 hours)
   - Watch for temperature stability
   - Ensure fans respond correctly
   - Check logs for errors

2. **Day 2-3**: Extended foreground testing
   - Run under load
   - Monitor for oscillations
   - Fine-tune curve if needed

3. **Day 4+**: Install as systemd service
   - Only after confirming stability
   - Keep monitoring for first week

## Emergency Procedures

### If Temperatures Rise Unexpectedly
```bash
# Stop nvmlfan immediately
sudo pkill nvmlfan

# Or restore default control
sudo ./nvmlfan --restore

# Verify fans are back to auto
nvidia-smi
```

### If Fans Stop Working
1. Stop nvmlfan: `sudo pkill nvmlfan`
2. Restore control: `sudo ./nvmlfan --restore`
3. Reduce GPU load if needed
4. Check system logs: `journalctl -xe`

## Installation (Only After Successful Testing)

```bash
# Build
go build nvmlfan.go

# Install binary
sudo install -o root -g root -m 755 ./nvmlfan /usr/local/sbin/nvmlfan

# Install systemd service
sudo install -o root -g root -m 644 ./nvmlfan.service /etc/systemd/system/nvmlfan.service

# Install your tested config
sudo install -o root -g root -m 644 /usr/local/etc/nvmlfan-test.yaml /usr/local/etc/nvmlfan.yaml

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable nvmlfan.service
sudo systemctl start nvmlfan.service

# Check status
sudo systemctl status nvmlfan.service
```

## Monitoring After Installation

```bash
# Check service status
sudo systemctl status nvmlfan.service

# View logs
sudo journalctl -u nvmlfan.service -f

# Stop service (restores default fan control)
sudo systemctl stop nvmlfan.service
```

## Signs Everything is Working

✅ Temperatures stay within safe range (under 85°C under load)
✅ Fans respond to temperature changes
✅ No error messages in logs
✅ System is stable under various loads
✅ Fan speeds adjust smoothly without rapid oscillations

## Red Flags to Watch For

❌ Temperature exceeds 85°C regularly
❌ Fans at 100% constantly
❌ Rapid fan speed oscillations (30% → 100% → 30%)
❌ Error messages about setting fan speed
❌ System freezes or GPU errors

## Additional Notes

- Your GPUs are currently under load (VLLM workers), making this a good real-world test
- GPU 1 is warmer (70°C) than GPU 0 (56°C) - this is normal for different workloads
- Both cards have 2 fans each, controlled together
- The software sets both fans to the same speed (limitation noted in README)
