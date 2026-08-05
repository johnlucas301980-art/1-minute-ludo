import { Router, type IRouter } from "express";

import {
  getWalletBalance,
  getWalletTransactions,
  requestRecharge,
  requestWithdraw,
} from "../controllers/wallet.controller.js";

const router: IRouter = Router();

/** GET /wallet/:playerId — current balance */
router.get("/wallet/:playerId", getWalletBalance);

/** GET /wallet/:playerId/transactions — history, newest first */
router.get("/wallet/:playerId/transactions", getWalletTransactions);

/** POST /wallet/recharge/request — credit points (no payment gateway) */
router.post("/wallet/recharge/request", requestRecharge);

/** POST /wallet/withdraw/request — debit points (no payment gateway) */
router.post("/wallet/withdraw/request", requestWithdraw);

export default router;
