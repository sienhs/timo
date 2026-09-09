import { randomBytes } from "crypto";
import { Signer, verifyMessage } from "ethers";

/**
 * Entry verification per spec: "동적 코드와 소유 지갑의 서명, 두 가지를 함께
 * 검증해 처리한다." Neither check alone is enough - a screenshotted QR
 * still has a valid signature on it (signatures don't expire on their own),
 * and a fresh code with someone else's forged signature shouldn't pass
 * either. The dynamic code's only job is to make a captured/replayed QR go
 * stale fast; the signature's only job is to prove current ownership.
 */

const DEFAULT_TTL_SECONDS = 15;

export interface DynamicCode {
  tokenId: string;
  code: string;
  issuedAt: number; // unix seconds
  expiresAt: number; // unix seconds
}

export interface EntryQrPayload {
  tokenId: string;
  code: string;
  expiresAt: number;
  signature: string;
}

export interface EntryVerificationResult {
  allowed: boolean;
  reason?: string;
  recoveredAddress?: string;
}

/**
 * Issues a fresh short-lived code for one ticket. In production this would
 * more likely be server-issued (so the client can't just mint itself an
 * arbitrarily long-lived one) - this stands in for that until backend/
 * exists.
 */
export function generateDynamicCode(tokenId: string, ttlSeconds = DEFAULT_TTL_SECONDS): DynamicCode {
  const issuedAt = Math.floor(Date.now() / 1000);
  return {
    tokenId,
    code: randomBytes(16).toString("hex"),
    issuedAt,
    expiresAt: issuedAt + ttlSeconds,
  };
}

/**
 * The ticket holder's app signs (tokenId, code, expiresAt) as one bundle,
 * which is what actually goes into the QR. Binding the signature to this
 * specific code+expiry means an old signature can't be paired with a new
 * code to extend its life, and a new signature can't be backdated onto an
 * expired code either.
 */
export async function signEntryQr(signer: Signer, dynamicCode: DynamicCode): Promise<EntryQrPayload> {
  const signature = await signer.signMessage(entryChallengeMessage(dynamicCode));
  return {
    tokenId: dynamicCode.tokenId,
    code: dynamicCode.code,
    expiresAt: dynamicCode.expiresAt,
    signature,
  };
}

/**
 * What the gate scanner runs on every scan - all three checks are
 * required:
 *   1. the code hasn't expired
 *   2. the code hasn't already been consumed (blocks a screenshot/replay
 *      of the exact same QR, including a legitimate holder scanning twice)
 *   3. the signature recovers to the ticket's *current* on-chain owner
 *
 * `currentOwner` and `consumedCodes` are passed in rather than owned by
 * this module: the caller is expected to have just read
 * TicketNFT.ownerOf(tokenId) (so this never checks against a stale cached
 * owner) and to hold consumedCodes in whatever shared store all gates read
 * from (a DB table in production - a Set works for this single-process
 * demo/test).
 */
export function verifyEntryQr(payload: EntryQrPayload, currentOwner: string, consumedCodes: Set<string>): EntryVerificationResult {
  const now = Math.floor(Date.now() / 1000);

  if (now > payload.expiresAt) {
    return { allowed: false, reason: "동적 코드 만료" };
  }
  if (consumedCodes.has(payload.code)) {
    return { allowed: false, reason: "이미 사용된 코드 (재사용/캡처 의심)" };
  }

  let recoveredAddress: string;
  try {
    recoveredAddress = verifyMessage(entryChallengeMessage(payload), payload.signature);
  } catch {
    return { allowed: false, reason: "서명 형식 오류" };
  }

  if (recoveredAddress.toLowerCase() !== currentOwner.toLowerCase()) {
    return { allowed: false, reason: "서명자와 현재 소유자 불일치", recoveredAddress };
  }

  consumedCodes.add(payload.code);
  return { allowed: true, recoveredAddress };
}

function entryChallengeMessage(dynamicCode: Pick<DynamicCode, "tokenId" | "code" | "expiresAt">): string {
  return `TIMO-ENTRY:${dynamicCode.tokenId}:${dynamicCode.code}:${dynamicCode.expiresAt}`;
}
