import { Router, type IRouter } from "express";
import { register, login, refresh, logout, googleSignIn, loginHistory } from "../controllers/auth.controller";
import { authenticate } from "../middlewares/authenticate";

const router: IRouter = Router();

router.post("/register", register);
router.post("/login", login);
router.post("/refresh", refresh);
router.post("/logout", authenticate, logout);
router.post("/google", googleSignIn);
router.get("/login-history", authenticate, loginHistory);

export default router;
