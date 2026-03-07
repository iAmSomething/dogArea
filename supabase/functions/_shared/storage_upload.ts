export type SharedStorageUploadErrorCode =
  | "STORAGE_UPLOAD_FAILED"
  | "PUBLIC_URL_FAILED";

export type SharedStorageUploadResult =
  | {
    ok: true;
    bucket: string;
    path: string;
    publicUrl: string;
  }
  | {
    ok: false;
    code: SharedStorageUploadErrorCode;
    message: string;
    bucket: string;
    path: string;
  };

export type SharedStorageUploadRequest = {
  bucket: string;
  path: string;
  bytes: Uint8Array;
  contentType: string;
  upsert?: boolean;
};

type StorageBucketClientLike = {
  upload: (
    path: string,
    bytes: Uint8Array,
    options: {
      contentType?: string;
      upsert?: boolean;
    },
  ) => Promise<{ error: { message?: string | null } | null }>;
  getPublicUrl: (
    path: string,
  ) => { data: { publicUrl?: string | null } | null };
};

type StorageClientLike = {
  storage: {
    from: (bucket: string) => StorageBucketClientLike;
  };
};

export type ProfileImageKind = "user" | "pet";
export type ProfileImageContentType = "image/jpeg" | "image/png";

const resolveProfileImageFileName = (
  imageKind: ProfileImageKind,
  contentType: ProfileImageContentType,
): string => {
  const fileExtension = contentType === "image/png" ? "png" : "jpeg";
  return imageKind === "pet" ? `petProfile.${fileExtension}` : `userProfile.${fileExtension}`;
};

export const uploadPublicStorageObject = async (
  client: StorageClientLike,
  request: SharedStorageUploadRequest,
): Promise<SharedStorageUploadResult> => {
  const bucketClient = client.storage.from(request.bucket);
  const upload = await bucketClient.upload(request.path, request.bytes, {
    contentType: request.contentType,
    upsert: request.upsert ?? true,
  });

  if (upload.error) {
    return {
      ok: false,
      code: "STORAGE_UPLOAD_FAILED",
      message: upload.error.message?.trim() || "storage upload failed",
      bucket: request.bucket,
      path: request.path,
    };
  }

  const publicData = bucketClient.getPublicUrl(request.path);
  const publicUrl = publicData.data?.publicUrl?.trim();

  if (!publicUrl) {
    return {
      ok: false,
      code: "PUBLIC_URL_FAILED",
      message: "public url is unavailable",
      bucket: request.bucket,
      path: request.path,
    };
  }

  return {
    ok: true,
    bucket: request.bucket,
    path: request.path,
    publicUrl,
  };
};

export const resolveProfileImageObjectPath = (
  ownerId: string,
  imageKind: ProfileImageKind,
  contentType: ProfileImageContentType,
): string => {
  const fileName = resolveProfileImageFileName(imageKind, contentType);
  return `${ownerId}/${fileName}`;
};

export const resolveAnonOnboardingProfileImageObjectPath = (
  ownerId: string,
  imageKind: ProfileImageKind,
  contentType: ProfileImageContentType,
): string => {
  const fileName = resolveProfileImageFileName(imageKind, contentType);
  return `anon-onboarding/${ownerId}/${fileName}`;
};

export const resolveCaricatureObjectPath = (
  ownerUserId: string,
  petId: string,
  jobId: string,
): string => `${ownerUserId}/${petId}/${jobId}.png`;
