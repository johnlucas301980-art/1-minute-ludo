import { Router, type IRouter } from "express";
import type { Request, Response, NextFunction } from "express";
import multer from "multer";
import { getProfile, updateProfile, changePassword, uploadAvatar } from "../controllers/profile.controller";
import { authenticate } from "../middlewares/authenticate";
import { avatarUpload } from "../lib/upload";

const router: IRouter = Router();

// ---------------------------------------------------------------------------
// Multer error wrapper for PUT /profile/avatar
//
// Runs the multer middleware and converts its errors to clean JSON responses
// before the uploadAvatar controller runs.  This keeps all error shaping in
// one place and avoids leaking multer internals to the client.
// ---------------------------------------------------------------------------

function handleAvatarUpload(req: Request, res: Response, next: NextFunction): void {
  avatarUpload.single("avatar")(req, res, (err: unknown) => {
    if (err instanceof multer.MulterError) {
      if (err.code === "LIMIT_FILE_SIZE") {
        res.status(400).json({
          success: false,
          message: "File is too large. Maximum allowed size is 2 MB.",
        });
        return;
      }
      res.status(400).json({ success: false, message: err.message });
      return;
    }

    if (err instanceof Error && err.message === "INVALID_MIME_TYPE") {
      res.status(400).json({
        success: false,
        message: "Invalid file type. Only JPEG, PNG, and WEBP images are allowed.",
      });
      return;
    }

    if (err) {
      next(err);
      return;
    }

    next();
  });
}

router.get("/profile", authenticate, getProfile);
router.put("/profile", authenticate, updateProfile);
router.put("/profile/password", authenticate, changePassword);
router.put("/profile/avatar", authenticate, handleAvatarUpload, uploadAvatar);

export default router;
