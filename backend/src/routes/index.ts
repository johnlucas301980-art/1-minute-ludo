import { Router, type IRouter } from "express";
import healthRouter from "./health";
import authRouter from "./auth";
import passwordResetRouter from "./password_reset";

const router: IRouter = Router();

router.use(healthRouter);
router.use("/auth", authRouter);
router.use("/auth", passwordResetRouter);

export default router;
