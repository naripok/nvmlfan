# Service Reliability and Safety Features

## Systemd Service Robustness

The nvmlfan systemd service is configured with multiple safety features to prevent GPU overheating if the service fails.

### Key Safety Features

#### 1. **Automatic Restart (`Restart=always`)**
If nvmlfan crashes or dies for any reason, systemd will automatically restart it within 5 seconds.

```
Restart=always
RestartSec=5
```

**What this protects against:**
- Segmentation faults
- Out of memory errors
- Unexpected crashes
- Process being killed

#### 2. **Unlimited Restart Attempts (`StartLimitBurst=0`)**
The service will keep trying to restart indefinitely, never giving up.

```
StartLimitBurst=0
```

**What this protects against:**
- Temporary configuration issues
- Transient driver problems
- System resource constraints

Without this, systemd would give up after a few failures.

#### 3. **Automatic Fan Restoration (`ExecStopPost`)**
Every time the service stops (for any reason), it restores GPU fans to automatic control.

```
ExecStopPost=/usr/local/sbin/nvmlfan --restore
```

**What this protects against:**
- Service crashes leaving fans in manual mode
- Fans stuck at last set speed
- GPUs overheating if service doesn't restart

**This is your primary safety mechanism.**

#### 4. **Graceful Shutdown Handling**
The nvmlfan code itself has signal handlers (SIGINT, SIGTERM) that restore fan control on exit:

```go
defer Shutdown(0)
signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
```

**What this protects against:**
- Clean shutdowns (`systemctl stop`)
- System reboots
- Process termination

## Failure Scenarios and Protections

### Scenario 1: nvmlfan Crashes
**What happens:**
1. Process dies immediately
2. `ExecStopPost` runs → fans restored to auto
3. Systemd waits 5 seconds
4. Systemd restarts the service
5. Fan control resumes

**Result:** Fans run on GPU auto control for ~5 seconds, then controlled again.

### Scenario 2: Config File Error
**What happens:**
1. Service fails to start
2. `ExecStopPost` runs → fans restored to auto (if they were changed)
3. Systemd waits 5 seconds
4. Systemd tries to restart
5. Process repeats indefinitely

**Result:** Fans stay on GPU auto control until config is fixed.

### Scenario 3: Binary Deleted/Corrupted
**What happens:**
1. Service fails to start
2. `ExecStopPost` runs (but may also fail)
3. Systemd keeps trying to restart

**Result:** Fans stay on GPU auto control. Requires manual intervention.

### Scenario 4: System Out of Memory
**What happens:**
1. Process is killed by OOM killer
2. `ExecStopPost` runs → fans restored
3. Systemd waits 5 seconds
4. Systemd restarts the service

**Result:** Brief period on auto control, then resumes.

### Scenario 5: Complete Systemd Failure
**What happens:**
System is likely having major issues. Fans stay on GPU auto control.

**Result:** GPUs use their built-in thermal management (default NVIDIA behavior).

## GPU Default Behavior (Failsafe)

When fans are restored to automatic control (or nvmlfan never starts), GPUs use NVIDIA's built-in thermal management:

- Fans adjust automatically based on temperature
- More conservative than custom curves
- Protects against overheating
- May run louder or hotter than your custom settings

**This is your ultimate failsafe** - even if everything else fails, GPUs won't overheat.

## Monitoring Service Health

### Check Service Status
```bash
sudo systemctl status nvmlfan.service
```

### View Service Logs
```bash
# Recent logs
sudo journalctl -u nvmlfan.service -n 50

# Follow live logs
sudo journalctl -u nvmlfan.service -f

# Logs since last boot
sudo journalctl -u nvmlfan.service -b
```

### Check for Restart Events
```bash
# Count how many times service has restarted
sudo journalctl -u nvmlfan.service | grep -c "Started Control of nvidia GPUs fans"

# Show restart events
sudo journalctl -u nvmlfan.service | grep "Started\|Stopped"
```

## Testing Failure Recovery

### Test 1: Kill the Process
```bash
# Kill the process
sudo pkill nvmlfan

# Wait a few seconds
sleep 6

# Check if it restarted
sudo systemctl status nvmlfan.service
```

Expected: Service should show as "active (running)" with a recent start time.

### Test 2: Stop and Check Fans
```bash
# Stop the service
sudo systemctl stop nvmlfan.service

# Check fan control is restored
nvidia-smi

# Start again
sudo systemctl start nvmlfan.service
```

Expected: Fans should revert to auto control when stopped.

### Test 3: Corrupt Config Temporarily
```bash
# Backup config
sudo cp /usr/local/etc/nvmlfan.yaml /usr/local/etc/nvmlfan.yaml.bak

# Break config
echo "invalid yaml" | sudo tee /usr/local/etc/nvmlfan.yaml

# Restart service
sudo systemctl restart nvmlfan.service

# Check status (should be failing but keep trying)
sudo systemctl status nvmlfan.service

# Restore config
sudo mv /usr/local/etc/nvmlfan.yaml.bak /usr/local/etc/nvmlfan.yaml

# Service should recover automatically within 5 seconds
```

Expected: Service keeps restarting, fans stay on auto, service recovers when config is fixed.

## What Could Still Go Wrong?

### Very Unlikely Scenarios

1. **Both systemd AND GPU drivers fail** - Extremely unlikely, system would have bigger problems
2. **Hardware failure** - Fan physically broken, no software can fix this
3. **Binary and restore command both corrupted** - Would require filesystem corruption
4. **NVIDIA driver crashes** - GPUs would likely crash regardless of fan control

### Additional Safety Layers (Optional)

If you're extremely paranoid, you could add:

1. **Monitoring with alerting** - Email/notify when service restarts
2. **Temperature-based system shutdown** - If GPUs exceed 90°C, shut down server
3. **External hardware monitoring** - IPMI or BMC monitoring

But for most cases, the current setup is very robust.

## Summary

**Your current protection layers:**

1. ✅ Service auto-restarts on failure (systemd)
2. ✅ Fans restored to auto on any stop (ExecStopPost)
3. ✅ Graceful shutdown handlers in code (defer/signal)
4. ✅ GPU built-in thermal protection (NVIDIA default)
5. ✅ Unlimited restart attempts (never gives up)

**Risk of GPU overheating due to nvmlfan failure:** **Very low**

The only real risk is catastrophic system failure, at which point GPU overheating is probably not your biggest concern.
