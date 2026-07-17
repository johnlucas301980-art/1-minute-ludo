import { Router, type IRouter } from "express";
import { getProfile, updateProfile, changePassword } from "../controllers/profile.controller";
import { authenticate } from "../middlewares/authenticate";

const router: IRouter = Router();

router.get("/profile", authenticate, getProfile);
router.put("/profile", authenticate, updateProfile);
router.put("/profile/password", authenticate, changePassword);

export default router;
