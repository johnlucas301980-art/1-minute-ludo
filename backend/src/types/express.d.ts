/**
 * Extends the Express Request type to include the authenticated user payload.
 * Set by the `authenticate` middleware after a valid access token is verified.
 */
declare namespace Express {
  interface Request {
    user?: {
      id: string;
      player_id: string;
    };
  }
}
