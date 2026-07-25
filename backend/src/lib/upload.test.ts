import { Readable } from "node:stream";
import { rm } from "node:fs/promises";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { AVATARS_DIR, MIME_TO_EXT, avatarUpload } from "./upload.js";

type UploadRequest = Readable & {
  headers: Record<string, string>;
  method: string;
  url: string;
  user?: { id: string; player_id: string };
  file?: { path: string; filename: string; mimetype: string };
};

function multipartRequest(
  mimetype: string,
  content: Buffer,
  userId = "user-1",
): UploadRequest {
  const boundary = "----vitest-avatar-boundary";
  const body = Buffer.concat([
    Buffer.from(
      `--${boundary}\r\n` +
        `Content-Disposition: form-data; name="avatar"; filename="avatar.bin"\r\n` +
        `Content-Type: ${mimetype}\r\n\r\n`,
    ),
    content,
    Buffer.from(`\r\n--${boundary}--\r\n`),
  ]);

  return Object.assign(Readable.from(body), {
    headers: {
      "content-type": `multipart/form-data; boundary=${boundary}`,
      "content-length": String(body.length),
    },
    method: "POST",
    url: "/profile/avatar",
    user: { id: userId, player_id: `player-${userId}` },
  });
}

async function runUpload(request: UploadRequest): Promise<Error | undefined> {
  return new Promise((resolve) => {
    avatarUpload.single("avatar")(request as never, {} as never, (error) => {
      resolve(error);
    });
  });
}

describe("avatar upload configuration", () => {
  it("maps supported image MIME types to canonical extensions", () => {
    expect(MIME_TO_EXT).toEqual({
      "image/jpeg": ".jpg",
      "image/png": ".png",
      "image/webp": ".webp",
    });
  });

  it("stores an allowed JPEG using the authenticated user ID", async () => {
    const request = multipartRequest("image/jpeg", Buffer.from("jpeg-data"), "user-42");

    const error = await runUpload(request);

    expect(error).toBeUndefined();
    expect(request.file).toMatchObject({
      filename: "user-42.jpg",
      mimetype: "image/jpeg",
    });
    await rm(path.join(AVATARS_DIR, "user-42.jpg"), { force: true });
  });

  it("rejects unsupported MIME types", async () => {
    const request = multipartRequest("application/pdf", Buffer.from("pdf-data"), "user-43");

    const error = await runUpload(request);

    expect(error).toBeInstanceOf(Error);
    expect(error?.message).toBe("INVALID_MIME_TYPE");
    expect(request.file).toBeUndefined();
  });

  it("enforces the two megabyte file-size limit", async () => {
    const request = multipartRequest(
      "image/png",
      Buffer.alloc(2 * 1024 * 1024 + 1),
      "user-44",
    );

    const error = await runUpload(request);

    expect(error).toMatchObject({ code: "LIMIT_FILE_SIZE" });
    expect(request.file).toBeUndefined();
    await rm(path.join(AVATARS_DIR, "user-44.png"), { force: true });
  });
});