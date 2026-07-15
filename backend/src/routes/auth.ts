import { Router, type IRouter } from "express";
import { register } from "../controllers/auth.controller";

const router: IRouter = Router();

router.post("/register", register);

export default router;
