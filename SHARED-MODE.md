# Shared Fan Control Mode

## Overview

The shared mode allows you to control multiple GPUs' fans together based on the **highest temperature** across all specified GPUs. This is useful when:

- You want consistent fan speeds across all GPUs
- One GPU runs hotter and you want all fans to respond
- You prefer a coordinated cooling approach across your system

## How It Works

Instead of controlling each GPU independently, shared mode:
1. Reads temperatures from all specified GPUs
2. Finds the **maximum temperature** among them
3. Calculates the appropriate fan speed based on that max temperature
4. Applies the **same fan speed** to all GPUs in the group

### Example Scenario

With your current setup:
- **GPU 0**: 52°C, fans at 84%
- **GPU 1**: 69°C, fans at 98%

In shared mode with the hottest temp (69°C):
- **GPU 0**: Will increase to ~97% (matching GPU 1's needs)
- **GPU 1**: Will run at ~97% (based on its temperature)

Both GPUs' fans will spin at the same speed determined by the hottest GPU.

## Configuration

### Basic Shared Mode (Curve)

```yaml
foreground: true
logging:
  level: debug
  type: stdout
period: 0.1

shared:
  mode: curve
  gpus: [0, 1]  # List of GPU indices to control together
  curve:
    - [40, 40]  # Below 40°C: 40% fan speed
    - [50, 60]  # At 50°C: 60% fan speed
    - [60, 80]  # At 60°C: 80% fan speed
    - [70, 100] # At 70°C: 100% fan speed
```

### Shared Mode with PID Control (Target)

```yaml
foreground: true
logging:
  level: debug
  type: stdout
period: 0.1

shared:
  mode: target
  gpus: [0, 1]
  target: 65      # Try to keep hottest GPU at 65°C
  pid: [20, 0.1, 0]
```

### Partial Shared Control

You can also control some GPUs in shared mode and others independently:

```yaml
# Control GPUs 0 and 1 together
shared:
  mode: curve
  gpus: [0, 1]
  curve:
    - [50, 40]
    - [70, 100]

# GPU 2 controlled independently (currently not supported - use one mode)
# This would require code changes to support mixed modes
```

**Note**: Currently, when `shared` is configured, it takes precedence over individual `cards` configuration.

## Comparison: Individual vs Shared

### Individual Control (Original Mode)

```yaml
cards:
  0:
    mode: curve
    curve:
      - [50, 40]
      - [70, 100]
  1:
    mode: curve
    curve:
      - [50, 40]
      - [70, 100]
```

**Result**: 
- GPU 0 at 52°C → fans at ~48%
- GPU 1 at 69°C → fans at ~97%
- **Different fan speeds** based on individual temperatures

### Shared Control

```yaml
shared:
  mode: curve
  gpus: [0, 1]
  curve:
    - [50, 40]
    - [70, 100]
```

**Result**:
- Max temp = 69°C (from GPU 1)
- GPU 0 fans → ~97% (based on GPU 1's temp)
- GPU 1 fans → ~97% (based on its own temp)
- **Same fan speeds** across all GPUs

## Benefits of Shared Mode

1. **Better Cooling**: Cooler GPUs help dissipate heat from hotter ones
2. **Predictable Acoustics**: All fans run at the same speed, more consistent noise
3. **Simpler Configuration**: One curve for all GPUs
4. **Cross-GPU Protection**: If one GPU heats up, all fans respond immediately

## Testing Shared Mode

1. **Stop the current service**:
   ```bash
   sudo systemctl stop nvmlfan.service
   ```

2. **Test in foreground**:
   ```bash
   cd /home/tau/Projects/nvmlfan
   sudo ./nvmlfan --foreground --config config-shared.yaml
   ```

3. **Watch the output** - you should see:
   - "Using shared control mode"
   - "maxTemp" showing the highest temperature
   - Both GPUs getting the same fan speed

4. **Monitor with nvidia-smi** (in another terminal):
   ```bash
   watch -n 1 nvidia-smi
   ```
   
   You should see both GPUs' fan speeds synchronized.

5. **Press Ctrl+C** to stop and restore default control

## Deploying Shared Mode

Once tested, update the production config:

```bash
# Stop the service
sudo systemctl stop nvmlfan.service

# Update the config
sudo cp /home/tau/Projects/nvmlfan/config-shared.yaml /usr/local/etc/nvmlfan.yaml

# Disable foreground mode for daemon operation
sudo sed -i 's/foreground: true/foreground: false/' /usr/local/etc/nvmlfan.yaml

# Restart the service
sudo systemctl start nvmlfan.service

# Check status
sudo systemctl status nvmlfan.service
```

## Troubleshooting

### Fans too loud
Both GPUs will run at the speed needed by the hottest one. To reduce noise:
- Lower the curve points
- Increase the temperature thresholds
- Use target mode with a higher target temperature

### One GPU much cooler than the other
This is expected in shared mode - the cooler GPU's fans will run faster than needed for its own temperature. This provides extra cooling capacity and helps overall system thermals.

### Want mixed control
Currently, shared mode controls all specified GPUs together. If you need mixed control (some shared, some individual), you would need code modifications or run multiple instances.
