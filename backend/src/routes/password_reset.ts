import { Router, type IRouter } from "express";
import {
  requestPasswordReset,
  verifyPasswordResetOtp,
  confirmPasswordReset,
} from "../controllers/password_reset.controller";

const router: IRouter = Router();

router.post("/password-reset/request", requestPasswordReset);
router.post("/password-reset/verify",  verifyPasswordResetOtp);
router.post("/password-reset/confirm", confirmPasswordReset);

export default router;
