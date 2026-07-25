# Backend Test Results - Waslny Captain

> Base URL: `https://wasalny-backend-production.up.railway.app/api/v1`
> Tested with JWT: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiJjbXJ3Z2IzZXUwMDAwbHIwcGN0cjQzZmM2Iiwicm9sZSI6IlJJREVSIiwiaWF0IjoxNzg0NzQ3MDQzLCJleHAiOjE3ODczMzkwNDN9.nukcWEd4m1Yonj98vw_6yzRjeXMjB82jF83ftKqApCM`
> Current user: RIDER role (not DRIVER)

---

## ✅ Working Endpoints

### Auth
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/auth/firebase-login` | POST | ✅ 200 | Full Firebase ID token → JWT exchange |
| `/auth/register-driver` | POST | ❌ 500 | See blocked list below |

### Wallet
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/wallet/balance` | GET | ✅ 200 | Returns `{"balance":0,"pendingWithdraw":0,"totalEarned":0,"totalWithdrawn":0,"fullName":""}` |
| `/wallet/top-up` | POST | ✅ Working | (Tested in previous session) |

### Rides
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/rides/history` | GET | ✅ 200 | Returns empty array `[]` (no rides yet) |

### User
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/user/profile` | GET | ❌ 404 | See blocked list below |
| `/user/profile/update` | PUT | ❓ Untested | Likely blocked same as profile |
| `/user/ratings/{userId}` | GET | ✅ 200 | Working (M9 fix from previous session) |

### Support
| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/support/messages` | GET | ✅ 200 | Returns empty messages array |
| `/support/messages` | POST | ❌ 500 | See blocked list below |

---

## ❌ Blocked/Deferred Backend Issues

### 1. `/auth/register-driver` → 500 Internal Server Error
- **Status**: ❌ Returns 500 even with ALL required fields including `phoneNumber`
- **Request sent**: `{phoneNumber, carModel, carPlateNumber, carColor, vehicleType, carPhotoUrl, name, email, photoUrl}`
- **Response**: `{"error":"حدث خطأ أثناء التسجيل ككابتن"}`
- **Root Cause**: Backend bug — cannot debug without Railway backend source code (not in local repo)
- **Severity**: 🔴 BLOCKING — users cannot complete registration

### 2. `ApiService.registerDriver()` missing `phoneNumber` field
- **Status**: ❌ Frontend-backend mismatch
- **File**: `lib/core/services/api_service.dart` (~line 185-210)
- **Issue**: Method sends `carModel`, `carPlateNumber`, `carColor`, `vehicleType`, `carPhotoUrl` but NOT `phoneNumber`
- **Backend validation**: Requires `phoneNumber` → returns 400 without it
- **Severity**: 🟡 Needs fixing even if backend 500 is resolved

### 3. `/driver/earnings?period=daily` → 404 Not Found
- **Status**: ❌ Endpoint doesn't exist on backend
- **Called by**: `home_screen.dart` → `_fetchStats()` → `ApiService.instance.getEarnings(period: 'daily')`
- **Impact**: Earnings always show 0 on home screen (wrapped in try-catch, app doesn't crash)
- **Existing Fix**: `EarningsRepository` calculates from `/rides/history` client-side but **is NOT used by home screen**
- **Severity**: 🟡 Low priority — non-critical, gracefully catches error

### 4. `/support/messages` POST → 500 Internal Server Error
- **Status**: ❌ Backend lacks `Message` model/table
- **Context**: Local `support.routes.js` was created (M7) but NOT deployed to Railway
- **Response**: 500 error when trying to send a message
- **Severity**: 🟡 Medium priority — core feature but app handles gracefully

### 5. `/user/profile` → 404 Not Found
- **Status**: ❌ Returns "المستخدم غير موجود"
- **Cause**: JWT user has `role: RIDER`, not `DRIVER`. The endpoint expects a driver profile.
- **Impact**: User profile data unavailable, but navigation works via Firestore (`DriverRepository`)
- **Severity**: 🔵 Expected behavior — not a real bug

### 6. Android Build — `flutter build apk` issues
- **Previous**: D8 InterruptedException (Gradle daemon crash)
- **Currently**: Clean build running since ~11:15 — actively compiling (Java CPU 128s, 982MB memory)
- **Status**: ⏳ In progress
- **Severity**: 🔴 BLOCKING — cannot test on device without successful build

---

## Frontend Code Details

### Login Flow (`lib/features/auth/login_screen.dart`)
- Google Sign-In → Firebase credential → backend JWT
- After success: checks `DriverRepository.getProfile(uid)` → vehicle-info OR home
- Error handling: FirebaseAuthException + ApiException → Arabic toast messages

### Vehicle Info (`lib/features/auth/vehicle_info_screen.dart`)
- Upload images → Create `DriverProfile` → Firestore save → `registerDriver()` API call
- **Known issue**: Missing `phoneNumber` in API call
- **Known issue**: Backend returns 500 for register-driver

### Home Screen (`lib/features/home/home_screen.dart`)
- `_fetchStats()`: calls `getEarnings('/driver/earnings')` → **404** ❌ and `getDriverRatings('/user/ratings/{userId}')` → **200** ✅
- Location updates every 15s via `Geolocator` when online
- Socket.io for real-time ride requests
- Real-time ride status tracking via `RealtimeService`
- Driver profile stream via Firestore

---

## Web Deferred
- Google Sign-In on web: `signInWithPopup` blocked by embedded browser popup blocker
- Error: "Unable to establish a connection with the popup. It may have been blocked by the browser."
- **Status**: ⏸️ Deferred — user switched to mobile testing
