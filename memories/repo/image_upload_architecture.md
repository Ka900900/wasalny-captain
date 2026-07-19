# Image Upload Architecture (Waslny Captain)

## Decision: Flutter NEVER uploads to Cloudinary directly.
- All image uploads go Flutter → Railway Backend (multipart/form-data, JWT Bearer) → Backend uploads to Cloudinary (Multer + Cloudinary SDK) → persists URL in PostgreSQL via Prisma → returns unified JSON.

## Backend (created in `backend/`, NOT in Firebase `functions/`)
- `backend/src/index.js` — Express server, mounts `/api/v1/upload`
- `backend/src/routes/upload.routes.js` — 5 endpoints, all `requireAuth` + `upload.single('image')`
- `backend/src/middleware/auth.js` — JWT Bearer verification
- `backend/src/middleware/upload.js` — Multer memoryStorage, 10MB, image-only
- `backend/src/cloudinary.js` — uploader.upload_stream to `waslny_captains/<subFolder>`
- `backend/prisma/schema.prisma` — `Captain` model with URL + publicId columns
- Endpoints: POST `/api/v1/upload/{profile|license|id-card|car|insurance}`
- Unified response: `{ success, imageUrl, publicId, message }`

## Flutter
- `lib/core/services/image_upload_service.dart` — `ImageUploadService` + `UploadType` enum. Uses `ApiService.baseUrl` + `ensureTokenReady()`.
- `ApiService.baseUrl` is a public getter over private `_baseUrl` (Railway URL).
- Removed: `cloudinary_service.dart`, `cloudinary_public` dep from pubspec.yaml.
- Screens rewired: registration, vehicle_info, edit_profile, profile.

## Gotcha
- `ApiService._baseUrl` is private → added `static String get baseUrl` for other services.
- Firebase `functions/` is Kashier-only; do NOT confuse with the Railway backend.
