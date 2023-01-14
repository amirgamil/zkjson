export type VerifyPayload = {
    isValidProof: boolean;
};

export interface EddsaSignature {
    A: BigInt[];
    msg: BigInt[];
    R8: BigInt[];
    S: BigInt[];
}

export interface ExtractedJSONSignature {
    packedSignature: Uint8Array;
    servicePubkey: Uint8Array;
    jsonText: string;
    formattedJSON: string;
}
