export type VerifyPayload = {
    isValidProof: boolean;
};

export interface EddsaSignature {
    pubKey: string[];
    msg: string[];
    R8: string[];
    S: string[];
}

export interface ExtractedJSONSignature {
    packedSignature: Uint8Array;
    servicePubkey: Uint8Array;
    jsonText: string;
    formattedJSON: string;
}
