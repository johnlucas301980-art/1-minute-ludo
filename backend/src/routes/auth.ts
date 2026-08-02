import { Router, type IRouter } from "express";
import { register, login, refresh, logout, googleSignIn } from "../controllers/auth.controller";
import { authenticate } from "../middlewares/authenticate";

const router: IRouter = Router();

router.post("/register", register);
router.post("/login", login);
router.post("/refresh", refresh);
router.post("/logout", authenticate, logout);
router.post("/google", googleSignIn);

export default router;
