# 🧪 SSE Background Reconnection - Testing Guide

## 🎯 **Overview**

This guide provides step-by-step testing instructions to verify the SSE background reconnection system works correctly across all edge cases.

---

## 🔧 **Prerequisites**

### **Requirements:**
- ✅ iOS device or simulator running iOS 18+
- ✅ Xcode 16+ for debug logging
- ✅ Active backend API (local or production)
- ✅ Test user account with available tokens

### **Setup:**
```bash
# 1. Open Xcode
open SketchWink.xcodeproj

# 2. Select target device
# Product → Destination → iPhone 15 (or physical device)

# 3. Build and run
# Product → Run (⌘R)
```

---

## 📋 **Test Scenarios**

### **TEST 1: Basic Background Recovery**
**Objective:** Verify SSE reconnects when app returns to foreground

**Steps:**
1. Launch app and sign in
2. Navigate to Generation screen
3. Create a new generation (any category/style)
4. Wait until you see progress bar at ~30%
5. **Press Home button** (minimize app)
6. Wait **90 seconds** (ensure iOS suspends SSE)
7. **Reopen app** (tap app icon)

**Expected Result:**
```
✅ App foregrounded
✅ Debug log: "📱 App became active (foregrounded)"
✅ Debug log: "📱 🔄 Reconnection needed"
✅ Debug log: "📱 📊 Generation status check: processing"
✅ Debug log: "🔁 Scheduling forced reconnect attempt"
✅ Progress bar updates to current status (60-90%)
✅ If completed: Shows "Your Art is Ready!"
```

**Debug Logs to Check:**
```
🔗 GenerationProgressSSE: 📱 App became active (foregrounded)
🔗 GenerationProgressSSE: 📱   Tracking generation: gen_xyz123
🔗 GenerationProgressSSE: 📱   SSE connected: false
🔗 GenerationProgressSSE: 📱   🔄 Reconnection needed - checking generation status first...
🔗 GenerationProgressSSE: 📱   📊 Generation status check:
🔗 GenerationProgressSSE: 📱      Status: processing
🔗 GenerationProgressSSE: 📱   ♻️ Generation still in progress, reconnecting SSE...
🔗 GenerationProgressSSE: 🔁 Scheduling forced reconnect attempt 1 in 1.0s
🔗 GenerationProgressSSE: Connected successfully
```

---

### **TEST 2: Completion While Backgrounded**
**Objective:** Verify app detects completion without reconnecting SSE

**Steps:**
1. Launch app and sign in
2. Create a new generation
3. **Immediately press Home button** (before progress starts)
4. Wait **3-4 minutes** (until generation completes)
5. **Reopen app**

**Expected Result:**
```
✅ App foregrounded
✅ Debug log: "📱 📊 Generation status check: completed"
✅ Debug log: "📱 🎉 Generation completed while backgrounded!"
✅ Shows completed artwork immediately
✅ No SSE reconnection attempt
✅ Token balance refreshed
```

**Debug Logs to Check:**
```
🔗 GenerationProgressSSE: 📱 App became active (foregrounded)
🔗 GenerationProgressSSE: 📱   🔄 Reconnection needed - checking generation status first...
🔗 GenerationProgressSSE: 📱   📊 Generation status check:
🔗 GenerationProgressSSE: 📱      Status: completed
🔗 GenerationProgressSSE: 📱      Images: 4
🔗 GenerationProgressSSE: 📱   🎉 Generation completed while backgrounded!
✅ GenerationProgressSSE: Token balance refreshed in global manager
```

---

### **TEST 3: Screen Lock During Generation**
**Objective:** Verify SSE handles screen locking gracefully

**Steps:**
1. Launch app and sign in
2. Create a new generation
3. Wait until progress reaches ~40%
4. **Press power button** (lock screen)
5. Wait **60 seconds**
6. **Press power button** (unlock screen)
7. **Swipe up / Face ID** (return to app)

**Expected Result:**
```
✅ Screen unlocks
✅ Debug log: "📱 App became active"
✅ Progress bar updates smoothly
✅ SSE reconnects if needed
```

**Note:** Screen lock triggers the same lifecycle events as backgrounding, so reconnection logic applies.

---

### **TEST 4: Control Center / Notification Center**
**Objective:** Verify SSE survives brief interruptions

**Steps:**
1. Launch app and sign in
2. Create a new generation
3. Wait until progress reaches ~50%
4. **Swipe down** (open Control Center or Notification Center)
5. Wait **5 seconds**
6. **Swipe up** (close Control Center/Notification Center)

**Expected Result:**
```
✅ App returns to active state
✅ Debug log: "📱 App will resign active"
✅ Debug log: "📱 App became active"
✅ SSE remains connected (no reconnection needed)
✅ Progress continues smoothly
```

**Why:** Brief interruptions (<30 seconds) don't trigger iOS suspension.

---

### **TEST 5: Polling Fallback Activation**
**Objective:** Verify polling activates when SSE reconnection fails

**Steps:**
1. Launch app and sign in
2. Create a new generation
3. Wait until progress reaches ~30%
4. **Enable Airplane Mode** (Settings → Airplane Mode ON)
5. **Press Home button** (background app)
6. Wait **60 seconds**
7. **Disable Airplane Mode** (Settings → Airplane Mode OFF)
8. **Reopen app**

**Expected Result:**
```
✅ App attempts SSE reconnection (fails due to network)
✅ Exponential backoff: 1s, 2s, 4s, 8s, 8s (5 attempts)
✅ Debug log: "❌ Max reconnect attempts (5) reached"
✅ Debug log: "⚡ Starting polling fallback (interval: 5.0s)"
✅ Debug log: "⚡ Polling generation status..." (every 5 seconds)
✅ Progress updates every 5 seconds
✅ Eventually shows completion
```

**Debug Logs to Check:**
```
🔗 GenerationProgressSSE: 🔁 Scheduling normal reconnect attempt 1 in 1.0s
🔗 GenerationProgressSSE: 🔁 Scheduling normal reconnect attempt 2 in 2.0s
🔗 GenerationProgressSSE: 🔁 Scheduling normal reconnect attempt 3 in 4.0s
🔗 GenerationProgressSSE: 🔁 Scheduling normal reconnect attempt 4 in 8.0s
🔗 GenerationProgressSSE: 🔁 Scheduling normal reconnect attempt 5 in 8.0s
🔗 GenerationProgressSSE: ❌ Max reconnect attempts (5) reached
🔗 GenerationProgressSSE: ⚡ Falling back to polling mode...
🔗 GenerationProgressSSE: ⚡ Starting polling fallback (interval: 5.0s)
🔗 GenerationProgressSSE: ⚡ Polling generation status...
🔗 GenerationProgressSSE: ⚡ Poll result: processing (50%)
🔗 GenerationProgressSSE: ⚡ Poll result: processing (50%)
🔗 GenerationProgressSSE: ⚡ Poll result: completed (100%)
🔗 GenerationProgressSSE: ⚡ ✅ Polling detected completion!
```

---

### **TEST 6: Network Switching (WiFi ↔ Cellular)**
**Objective:** Verify SSE handles network changes

**Steps:**
1. Launch app on **WiFi**
2. Create a new generation
3. Wait until progress reaches ~40%
4. **Disable WiFi** (Settings → WiFi OFF)
5. Wait **10 seconds** (switch to cellular)
6. Let generation continue

**Expected Result:**
```
✅ SSE connection drops
✅ Debug log: "Connection completed/disconnected"
✅ Debug log: "🔁 Scheduling normal reconnect attempt 1"
✅ SSE reconnects successfully on cellular
✅ Progress continues smoothly
```

---

### **TEST 7: Multiple Backgrounding Cycles**
**Objective:** Verify system handles repeated background/foreground cycles

**Steps:**
1. Launch app and create generation
2. Wait until ~20% progress
3. **Background app** (Home button)
4. Wait **30 seconds**
5. **Foreground app**
6. Wait until ~40% progress
7. **Background app again**
8. Wait **30 seconds**
9. **Foreground app again**

**Expected Result:**
```
✅ First background → First foreground: Reconnects successfully
✅ Second background → Second foreground: Reconnects successfully
✅ Reconnect attempt counter resets after successful connection
✅ No polling fallback activation
✅ Generation completes normally
```

---

### **TEST 8: Immediate Foreground Return**
**Objective:** Verify no unnecessary reconnection if SSE still alive

**Steps:**
1. Launch app and create generation
2. Wait until ~30% progress
3. **Background app** (Home button)
4. **Immediately foreground app** (<5 seconds)

**Expected Result:**
```
✅ App returns to foreground
✅ Debug log: "📱 App became active"
✅ Debug log: "✅ SSE still connected, no reconnection needed"
✅ No reconnection attempt
✅ Progress continues without interruption
```

---

### **TEST 9: Long Background Period (5+ minutes)**
**Objective:** Verify system handles extended backgrounding

**Steps:**
1. Launch app and create generation
2. Wait until ~20% progress
3. **Background app** (Home button)
4. Wait **5 minutes**
5. **Foreground app**

**Expected Result:**
```
✅ App foregrounded
✅ Generation status polled
✅ Shows completed result (if finished)
✅ OR reconnects SSE (if still in progress)
✅ Token balance refreshed on completion
```

---

### **TEST 10: Generation Failure While Backgrounded**
**Objective:** Verify failure detection without reconnection

**Steps:**
1. Launch app and create generation
2. **Background app immediately**
3. Wait **2 minutes**
4. **(Manually trigger backend failure if possible, or wait for natural failure)**
5. **Foreground app**

**Expected Result:**
```
✅ App foregrounded
✅ Debug log: "📱 📊 Generation status check: failed"
✅ Debug log: "📱 ❌ Generation failed while backgrounded"
✅ Shows error message to user
✅ No SSE reconnection attempt
```

---

## 🔍 **Debugging Tips**

### **Enable Comprehensive Logging:**
All debug logs are already wrapped in `#if DEBUG` blocks. To see them:

```bash
# 1. Run in Debug configuration (default in Xcode)
# 2. Open Xcode Console (⌘⇧Y)
# 3. Filter logs by: "GenerationProgressSSE"
```

### **Common Debug Log Patterns:**

**Successful Foreground Recovery:**
```
📱 App became active (foregrounded)
   Tracking generation: gen_xyz
   SSE connected: false
   🔄 Reconnection needed
   📊 Generation status check: processing
   ♻️ Generation still in progress, reconnecting SSE
🔁 Scheduling forced reconnect attempt 1
Connected successfully
```

**Completion While Backgrounded:**
```
📱 App became active (foregrounded)
   📊 Generation status check: completed
   🎉 Generation completed while backgrounded!
✅ Token balance refreshed
```

**Polling Fallback:**
```
❌ Max reconnect attempts (5) reached
⚡ Starting polling fallback
⚡ Polling generation status...
⚡ Poll result: processing (70%)
⚡ ✅ Polling detected completion!
```

---

## 📊 **Expected Behavior Summary**

| Scenario | SSE Reconnect? | Polling? | Status Check? | Result |
|----------|----------------|----------|---------------|--------|
| Foreground with active generation | ✅ Yes | ❌ No | ✅ Yes | Progress updates |
| Foreground with completed generation | ❌ No | ❌ No | ✅ Yes | Shows result |
| SSE fails 5 times | ❌ No | ✅ Yes | ✅ Yes | Polling mode |
| Brief interruption (<30s) | ❌ No | ❌ No | ❌ No | SSE still alive |
| Screen lock | ✅ Yes | ❌ No | ✅ Yes | Reconnects on unlock |

---

## 🐛 **Troubleshooting**

### **Issue: No reconnection happens**
**Check:**
- [ ] Is `trackingGenerationId` set? (Check debug logs)
- [ ] Is `lastAuthToken` available? (Should be stored from initial connection)
- [ ] Are lifecycle observers registered? (Check for "Setting up app lifecycle observers")

**Fix:**
- Ensure generation was started successfully
- Verify user is authenticated
- Check that `setupAppLifecycleObservers()` is called in `init()`

---

### **Issue: Polling activates immediately**
**Check:**
- [ ] Network connectivity (SSE requires stable connection)
- [ ] Backend SSE endpoint is working (`/api/sse/user-progress`)
- [ ] Auth token is valid

**Fix:**
- Test SSE manually: `curl -H "Authorization: Bearer TOKEN" http://localhost:3000/api/sse/user-progress`
- Check backend logs for SSE connection errors
- Verify auth token hasn't expired

---

### **Issue: Progress stuck at specific percentage**
**Check:**
- [ ] Is SSE connection actually alive? (Check `isConnected` property)
- [ ] Is polling active? (Check for "⚡ Polling" logs)
- [ ] Is generation actually progressing on backend?

**Fix:**
- Check backend logs for generation status
- Manually query generation: `GET /api/generations/:id`
- Force polling mode for debugging

---

### **Issue: Memory leak concerns**
**Check:**
- [ ] Are observers removed in `deinit`?
- [ ] Are timers invalidated in `deinit`?
- [ ] Are there retain cycles in closures?

**Fix:**
- Verify `deinit` is called (add debug log)
- Ensure `[weak self]` in all closures
- Use Instruments → Leaks to detect memory issues

---

## ✅ **Testing Checklist**

- [ ] TEST 1: Basic background recovery ✅
- [ ] TEST 2: Completion while backgrounded ✅
- [ ] TEST 3: Screen lock during generation ✅
- [ ] TEST 4: Control Center interruption ✅
- [ ] TEST 5: Polling fallback activation ✅
- [ ] TEST 6: Network switching (WiFi ↔ Cellular) ✅
- [ ] TEST 7: Multiple backgrounding cycles ✅
- [ ] TEST 8: Immediate foreground return ✅
- [ ] TEST 9: Long background period (5+ min) ✅
- [ ] TEST 10: Generation failure while backgrounded ✅

---

## 🎉 **Success Criteria**

Your implementation is **production-ready** when:

1. ✅ All 10 test scenarios pass
2. ✅ No memory leaks detected (Instruments → Leaks)
3. ✅ Debug logs show expected patterns
4. ✅ User sees updated progress on foreground (no stuck UI)
5. ✅ Polling fallback activates only when SSE fails
6. ✅ Token balance refreshes on completion
7. ✅ No crashes or unexpected behavior
8. ✅ Works on both simulator and physical device

---

## 📝 **Test Report Template**

```markdown
# SSE Background Reconnection - Test Report

**Date:** [Date]
**Tester:** [Name]
**Device:** [iPhone 15 / Physical Device]
**iOS Version:** [18.0]

## Test Results

| Test # | Scenario | Status | Notes |
|--------|----------|--------|-------|
| 1 | Basic background recovery | ✅ Pass | |
| 2 | Completion while backgrounded | ✅ Pass | |
| 3 | Screen lock | ✅ Pass | |
| 4 | Control Center | ✅ Pass | |
| 5 | Polling fallback | ✅ Pass | |
| 6 | Network switching | ✅ Pass | |
| 7 | Multiple cycles | ✅ Pass | |
| 8 | Immediate return | ✅ Pass | |
| 9 | Long background | ✅ Pass | |
| 10 | Failure detection | ✅ Pass | |

## Issues Found
[List any issues or unexpected behavior]

## Recommendations
[Suggestions for improvement]
```

---

**Last Updated:** January 23, 2025
**Implementation:** GenerationProgressSSEService.swift
**Status:** ✅ Ready for Testing
