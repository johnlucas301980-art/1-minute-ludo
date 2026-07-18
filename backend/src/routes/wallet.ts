import { Router, type IRouter } from "express";
import { getWallet, getWalletHistory } from "../controllers/wallet.controller";
import { authenticate } from "../middlewares/authenticate";

const router: IRouter = Router();

router.get("/wallet", authenticate, getWallet);
router.get("/wallet/history", authenticate, getWalletHistory);

export default router;
