/**
 * Multer upload configuration for avatar images.
 *
 * - Storage : local disk at backend/uploads/avatars/
 * - Filename : <user-id>.<ext>  (one file per user — new upload replaces old)
 * - Allowed  : image/jpeg, image/png, image/webp
 * - Max size : 2 MB
 *
 * The uploads directory is created automatically on first use.
 * Exported constants let other modules resolve file paths consistently.
 */

import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import multer from "multer";

// ---------------------------------------------------------------------------
// Directory
// ---------------------------------------------------------------------------

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** Absolute path to the avatars upload directory.
 *
 * esbuild bundles all source files into dist/index.mjs, so at runtime
 * import.meta.url always points to dist/index.mjs regardless of which
 * source file the code originated in.  One level up from dist/ reaches
 * the backend root where uploads/ lives.
 */
export const AVATARS_DIR = path.resolve(__dirname, "../uploads/avatars");

// Ensure the directory exists at module load time (idempotent).
fs.mkdirSync(AVATARS_DIR, { recursive: true });

// ---------------------------------------------------------------------------
// MIME type configuration
// ---------------------------------------------------------------------------

const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

/** Maps an allowed MIME type to its canonical file extension. */
export const MIME_TO_EXT: Record<string, string> = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
};

// ---------------------------------------------------------------------------
// Multer instance
// ---------------------------------------------------------------------------

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, AVATARS_DIR);
  },
  filename: (req, file, cb) => {
    const ext = MIME_TO_EXT[file.mimetype] ?? ".jpg";
    // req.user is set by the authenticate middleware which runs before multer.
    const userId = (req as Express.Request).user?.id ?? "unknown";
    cb(null, `${userId}${ext}`);
  },
});

const fileFilter: multer.Options["fileFilter"] = (_req, file, cb) => {
  if (ALLOWED_MIME_TYPES.has(file.mimetype)) {
    cb(null, true);
  } else {
    // Use a coded error message so the route wrapper can produce a clean JSON response.
    cb(new Error("INVALID_MIME_TYPE"));
  }
};

/** Pre-configured multer instance for avatar uploads. */
export const avatarUpload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 2 * 1024 * 1024, // 2 MB
  },
});
