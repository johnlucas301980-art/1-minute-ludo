import { Router, type IRouter } from "express";
import healthRouter from "./health";
import authRouter from "./auth";
import passwordResetRouter from "./password_reset";
import profileRouter from "./profile";

const router: IRouter = Router();

router.use(healthRouter);
router.use("/auth", authRouter);
router.use("/auth", passwordResetRouter);
router.use(profileRouter);

export default router;
