import { Router, type IRouter } from "express";
import healthRouter from "./health";
import authRouter from "./auth";
import passwordResetRouter from "./password_reset";
import profileRouter from "./profile";
import walletRouter from "./wallet";
import matchmakingRouter from "./matchmaking";
import historyRouter from "./history";

const router: IRouter = Router();

router.use(healthRouter);
router.use("/auth", authRouter);
router.use("/auth", passwordResetRouter);
router.use(profileRouter);
router.use(walletRouter);
router.use(matchmakingRouter);
router.use(historyRouter);

export default router;
