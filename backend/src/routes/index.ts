import { Router, type IRouter } from "express";
import healthRouter        from "./health.js";
import authRouter          from "./auth.js";
import passwordResetRouter from "./password_reset.js";
import profileRouter       from "./profile.js";
import walletRouter        from "./wallet.js";
import matchmakingRouter   from "./matchmaking.js";
import historyRouter       from "./history.js";
import leaderboardRouter   from "./leaderboard.js";
import notificationsRouter from "./notifications.js";
import supportRouter       from "./support.js";
import adminRouter         from "./admin.js";
import countryRouter       from "./country.js";
import gameRouter          from "./game.js";

const router: IRouter = Router();

router.use(healthRouter);
router.use("/auth", authRouter);
router.use("/auth", passwordResetRouter);
router.use(profileRouter);
router.use(walletRouter);
router.use(matchmakingRouter);
router.use(historyRouter);
router.use(leaderboardRouter);
router.use(notificationsRouter);
router.use(supportRouter);
router.use(adminRouter);
router.use(countryRouter);
router.use(gameRouter);

export default router;
