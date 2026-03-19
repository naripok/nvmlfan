# Shared Fan Control - Quick Start

## What You Have Now

✅ **Shared mode implemented and tested**
- Both GPUs' fans are controlled together
- Fan speed based on the **hottest GPU**
- GPU 0 (51°C) and GPU 1 (70°C) both running at same speed

## How to Deploy

### Step 1: Stop Current Service
```bash
sudo systemctl stop nvmlfan.service
```

### Step 2: Test Shared Mode
```bash
cd /home/tau/Projects/nvmlfan
sudo ./nvmlfan --foreground --config config-shared.yaml
```

Watch for a few minutes to ensure both GPUs' fans are synchronized and temperatures are stable.

### Step 3: Deploy to Production

Once satisfied with testing:

```bash
# Copy shared config to production
sudo cp /home/tau/Projects/nvmlfan/config-shared.yaml /usr/local/etc/nvmlfan.yaml

# Disable foreground mode
sudo sed -i 's/foreground: true/foreground: false/' /usr/local/etc/nvmlfan.yaml

# Install updated binary
sudo install -o root -g root -m 755 /home/tau/Projects/nvmlfan/nvmlfan /usr/local/sbin/nvmlfan

# Restart service
sudo systemctl start nvmlfan.service

# Verify it's working
sudo systemctl status nvmlfan.service
```

### Step 4: Monitor
```bash
# Check logs
sudo journalctl -u nvmlfan.service -f

# Watch GPU stats
watch -n 1 'nvidia-smi --query-gpu=index,temperature.gpu,fan.speed --format=csv'
```

You should see both GPUs' fan speeds stay in sync.

## Configuration Options

### Current Config (config-shared.yaml)
```yaml
shared:
  mode: curve
  gpus: [0, 1]
  curve:
    - [40, 40]  # At 40°C: 40% fan
    - [50, 60]  # At 50°C: 60% fan
    - [60, 80]  # At 60°C: 80% fan
    - [70, 100] # At 70°C: 100% fan
```

### Adjust for Your Preferences

**Too loud?** Reduce fan speeds:
```yaml
curve:
  - [40, 30]
  - [55, 50]
  - [65, 70]
  - [75, 100]
```

**Want more aggressive cooling?**
```yaml
curve:
  - [35, 40]
  - [45, 70]
  - [55, 90]
  - [65, 100]
```

## Switching Back to Individual Control

If you want to go back to per-GPU control:

```bash
sudo systemctl stop nvmlfan.service
sudo cp /home/tau/Projects/nvmlfan/config-test-conservative.yaml /usr/local/etc/nvmlfan.yaml
sudo sed -i 's/foreground: true/foreground: false/' /usr/local/etc/nvmlfan.yaml
sudo systemctl start nvmlfan.service
```

## Benefits You'll See

1. **GPU 0's fans will help cool the system** when GPU 1 gets hot
2. **Consistent fan noise** - both cards at same speed
3. **Better overall cooling** - more airflow through the case
4. **Simpler configuration** - one curve for all GPUs

## Current Status

- ✅ Code implemented and compiled
- ✅ Tested successfully (both GPUs at 100% when hottest is 70°C)
- ✅ Currently running old individual mode in production
- ⏳ Ready to deploy shared mode when you're ready
