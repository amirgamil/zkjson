export type VerifyPayload = {
    isValidProof: boolean;
};

export interface EddsaSignature {
    A: BigInt[];
    msg: BigInt[];
    R8: BigInt[];
    S: BigInt[];
}
