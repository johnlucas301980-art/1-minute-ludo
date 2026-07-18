import { Router, type IRouter } from "express";
import {
  getWallet,
  getWalletHistory,
  deposit,
  withdraw,
} from "../controllers/wallet.controller";
import { authenticate } from "../middlewares/authenticate";

const router: IRouter = Router();

router.get("/wallet", authenticate, getWallet);
router.get("/wallet/history", authenticate, getWalletHistory);
router.post("/wallet/deposit", authenticate, deposit);
router.post("/wallet/withdraw", authenticate, withdraw);

export default router;
