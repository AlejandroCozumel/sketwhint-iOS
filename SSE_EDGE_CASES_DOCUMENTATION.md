# 📡 SSE Background Reconnection - Edge Cases Documentation

## 🎯 **Overview**

This document comprehensively explains all edge cases handled by the SSE (Server-Sent Events) reconnection system in SketchWink iOS app, specifically addressing the **iOS background suspension problem**.

---

## 🚨 **THE CORE PROBLEM**

**iOS suspends network connections when the app is backgrounded/minimized.**

This is NOT a backend issue - it's an **iOS platform limitation** designed to preserve battery and system resources.

### **iOS Background Behavior:**

1. **App in Foreground** → ✅ SSE connection alive, real-time updates working
2. **User minimizes app** → iOS suspends URLSession after ~30 seconds → SSE dies
3. **User returns to app** → Old SSE connection is DEAD → No reconnect without manual intervention

**Result without fix:** User sees stale UI (stuck at "Processing 30%" forever)

---

## ✅ **COMPLETE EDGE CASE SOLUTIONS**

### **EDGE CASE 1: No Active Generation**
**Scenario:** User backgrounded app but no generation was in progress

**Solution:**
```swift
guard let trackingId = trackingGenerationId, !trackingId.isEmpty else {
    // No active generation, no action needed
    return
}
```

**Result:** ✅ No unnecessary reconnection attempts, conserves resources

---

### **EDGE CASE 2: SSE Survived Backgrounding**
**Scenario:** App returned to foreground before iOS suspended SSE (rare, <30 seconds)

**Solution:**
```swift
guard !isConnected else {
    // SSE still connected, no reconnection needed
    return
}
```

**Result:** ✅ Avoids redundant reconnections, keeps existing connection alive

---

### **EDGE CASE 3: Generation Already Finished**
**Scenario:** Generation completed via existing SSE before app backgrounded

**Solution:**
```swift
if let status = currentProgress?.status, status == .completed || status == .failed {
    // Generation already finished, no need to reconnect
    return
}
```

**Result:** ✅ Prevents unnecessary reconnection for finished generations

---

### **EDGE CASE 4: Generation Completed While Backgrounded**
**Scenario:** User backgrounded app for 2 minutes, generation completed during that time

**Solution:**
```swift
// Poll generation status FIRST before reconnecting SSE
let generation = try await GenerationService.shared.getGeneration(id: trackingId)

if generation.status == .completed {
    self.stopPollingFallback()
    await TokenBalanceManager.shared.refresh()
    self.onGenerationComplete?(generation.id)
    return  // Don't reconnect SSE
}
```

**Result:** ✅ User sees completed result immediately, no wasted SSE reconnection

---

### **EDGE CASE 5: Generation Failed While Backgrounded**
**Scenario:** Generation failed during background period

**Solution:**
```swift
if generation.status == .failed {
    self.stopPollingFallback()
    let error = GenerationProgressError.generationFailed("Generation failed")
    self.onError?(error)
    return  // Don't reconnect SSE
}
```

**Result:** ✅ User sees error message, can retry generation

---

### **EDGE CASE 6: Generation Still In Progress**
**Scenario:** User backgrounded for 1 minute, generation still processing

**Solution:**
```swift
// Generation still in progress - reconnect SSE
self.stopPollingFallback()
self.scheduleReconnect(force: true)
```

**Result:** ✅ SSE reconnects, user continues receiving real-time updates

---

### **EDGE CASE 7: Max Reconnect Attempts Reached**
**Scenario:** Network issues prevent SSE reconnection after 5 attempts

**Solution:**
```swift
guard self.reconnectAttempt < self.maxReconnectAttempts else {
    // Max reconnect attempts reached - fall back to polling
    self.startPollingFallback()
    return
}
```

**Result:** ✅ Automatic fallback to polling (5-second intervals), progress updates continue

---

### **EDGE CASE 8: Polling Detected Completion**
**Scenario:** Polling mode detected generation completed

**Solution:**
```swift
if generation.status == .completed {
    self.stopPollingFallback()
    await TokenBalanceManager.shared.refresh()
    self.onGenerationComplete?(generation.id)
    return
}
```

**Result:** ✅ Polling stops, user sees completed generation, tokens refreshed

---

### **EDGE CASE 9: Polling Detected Failure**
**Scenario:** Polling mode detected generation failed

**Solution:**
```swift
if generation.status == .failed {
    self.stopPollingFallback()
    let error = GenerationProgressError.generationFailed("Generation failed")
    self.onError?(error)
    return
}
```

**Result:** ✅ Polling stops, user sees error message

---

### **EDGE CASE 10: Polling Encountered Error**
**Scenario:** Network error during polling request

**Solution:**
```swift
catch {
    // Don't stop polling on transient errors (network issues, etc.)
    // Keep trying - only stop if generation is explicitly finished
}
```

**Result:** ✅ Polling continues through transient network errors, eventually recovers

---

## 📱 **APP LIFECYCLE OBSERVERS**

### **Notifications Monitored:**

1. **`UIApplication.willResignActiveNotification`**
   - Triggers: App backgrounding, Control Center, screen lock
   - Action: Log event, prepare for suspension

2. **`UIApplication.didEnterBackgroundNotification`**
   - Triggers: App fully backgrounded
   - Action: Mark `isAppInBackground = true`

3. **`UIApplication.willEnterForegroundNotification`**
   - Triggers: App about to become active
   - Action: Mark `isAppInBackground = false`

4. **`UIApplication.didBecomeActiveNotification`**
   - Triggers: App foregrounded, unlocked, returned from Control Center
   - Action: **Check generation status → Reconnect SSE if needed**

---

## ⚡ **POLLING FALLBACK MECHANISM**

### **When Polling Activates:**
- SSE reconnection failed after 5 attempts (exponential backoff: 1s, 2s, 4s, 8s, 8s)

### **Polling Behavior:**
- **Interval:** 5 seconds
- **Endpoint:** `GET /api/generations/:id`
- **Updates:** Progress bar, status messages, completion detection
- **Stop Conditions:** Generation completed, failed, or manual disconnect

### **Polling vs SSE Comparison:**

| Feature | SSE (Normal) | Polling (Fallback) |
|---------|--------------|-------------------|
| **Latency** | Instant (real-time) | 5-second delay |
| **Efficiency** | High (server push) | Lower (repeated requests) |
| **Reliability** | Depends on connection | Works with spotty network |
| **Battery Impact** | Low | Moderate |
| **Use Case** | Foreground, stable network | Background recovery, unstable network |

---

## 🔄 **RECONNECTION STRATEGY**

### **Exponential Backoff:**
```
Attempt 1: 1 second delay
Attempt 2: 2 seconds delay
Attempt 3: 4 seconds delay
Attempt 4: 8 seconds delay (capped)
Attempt 5: 8 seconds delay (max attempts)
After attempt 5: Fall back to polling
```

### **Force Reconnect Scenarios:**
- App foregrounded with active generation
- Network recovered after connectivity loss
- Manual reconnection triggered

---

## 🧪 **TESTING SCENARIOS**

### **Test 1: Basic Backgrounding**
1. Start generation
2. Wait until 30% progress (SSE working)
3. Minimize app
4. Wait 1 minute
5. Return to app
6. **Expected:** Progress bar updates to current status (60% or completed)

### **Test 2: Long Background Period**
1. Start generation
2. Minimize app immediately
3. Wait 5 minutes (generation completes)
4. Return to app
5. **Expected:** Completed result shown immediately, no SSE reconnection

### **Test 3: Network Switching**
1. Start generation on WiFi
2. Switch to cellular during generation
3. **Expected:** SSE reconnects automatically, progress continues

### **Test 4: Poor Network Conditions**
1. Start generation
2. Enable poor network simulation (airplane mode toggle)
3. **Expected:** SSE fails → Polling activates → Progress updates continue every 5s

### **Test 5: Screen Lock**
1. Start generation
2. Lock screen (Control Center → Lock)
3. Wait 1 minute
4. Unlock screen
5. **Expected:** Progress bar updates to current status

### **Test 6: Control Center / Notification Center**
1. Start generation
2. Open Control Center
3. Close Control Center
4. **Expected:** SSE remains connected (quick interruption doesn't trigger suspension)

---

## 🐛 **DEBUGGING**

### **Debug Logs to Monitor:**

```
🔗 GenerationProgressSSE: Setting up app lifecycle observers
🔗 GenerationProgressSSE: 📱 App will resign active
🔗 GenerationProgressSSE: 📱 App entered background
🔗 GenerationProgressSSE: 📱 App became active (foregrounded)
🔗 GenerationProgressSSE: 📱   🔄 Reconnection needed
🔗 GenerationProgressSSE: 📱   📊 Generation status check: processing
🔗 GenerationProgressSSE: 📱   ♻️ Generation still in progress, reconnecting SSE
🔗 GenerationProgressSSE: 🔁 Scheduling forced reconnect attempt 1 in 1.0s
🔗 GenerationProgressSSE: ⚡ Starting polling fallback (interval: 5.0s)
🔗 GenerationProgressSSE: ⚡ Poll result: completed (100%)
🔗 GenerationProgressSSE: ⚡ ✅ Polling detected completion!
```

### **Common Issues:**

**Issue:** App returns, no progress updates
- **Check:** Is `trackingGenerationId` set?
- **Check:** Is `lastAuthToken` available?
- **Check:** Are lifecycle observers registered?

**Issue:** Polling activates too quickly
- **Check:** Is `maxReconnectAttempts = 5` (not lower)?
- **Check:** Network stability (SSE may fail immediately on bad network)

**Issue:** Memory leak concerns
- **Check:** `deinit` removes all observers
- **Check:** All timers invalidated (`stopWatchdog()`, `stopPollingFallback()`)

---

## 📊 **METRICS & MONITORING**

### **Key Metrics to Track:**
1. **SSE Reconnection Success Rate** - % of successful reconnections
2. **Polling Activation Rate** - How often polling fallback is needed
3. **Background Recovery Time** - Time from foregrounding to progress update
4. **Completion Detection Accuracy** - % of generations properly detected as complete

### **Production Logging (Remove Debug Logs):**
```swift
#if DEBUG
// All detailed logs are wrapped in DEBUG flags
// Production builds will have minimal logging
#endif
```

---

## ✅ **FINAL VERIFICATION CHECKLIST**

- [x] App lifecycle observers registered in `init()`
- [x] Observers removed in `deinit` (prevent memory leaks)
- [x] All 10 edge cases handled with specific logic
- [x] Polling fallback implemented with proper cleanup
- [x] Exponential backoff for reconnection attempts
- [x] Force reconnect on app foregrounding
- [x] Generation status polling before SSE reconnection
- [x] Token balance refresh on completion
- [x] Debug logging for all critical paths
- [x] Timers properly invalidated on cleanup

---

## 🎯 **CONCLUSION**

This implementation provides a **bulletproof** SSE reconnection system that handles all known iOS backgrounding edge cases. The system automatically:

1. ✅ Detects app backgrounding/foregrounding
2. ✅ Polls generation status before reconnecting
3. ✅ Reconnects SSE with exponential backoff
4. ✅ Falls back to polling if SSE fails
5. ✅ Handles network switching and poor connectivity
6. ✅ Properly cleans up resources to prevent memory leaks
7. ✅ Provides detailed debug logging for troubleshooting

**No user action required** - the system handles everything automatically!

---

**Last Updated:** January 23, 2025
**Implementation:** GenerationProgressSSEService.swift
**Status:** ✅ Production Ready
