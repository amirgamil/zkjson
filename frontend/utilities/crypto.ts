import { EddsaSignature } from "./types";

const buildEddsa = require("circomlibjs").buildEddsa;
const buildBabyjub = require("circomlibjs").buildBabyjub;

let eddsa;
let babyJub;

function buffer2bits(buff: any) {
    const res = [];
    for (let i = 0; i < buff.length; i++) {
        for (let j = 0; j < 8; j++) {
            if ((buff[i] >> j) & 1) {
                res.push(BigInt(1));
            } else {
                res.push(BigInt(0));
            }
        }
    }
    return res;
}

export const generateEddsaSignature = async (privateKey: Uint8Array, msg: Uint8Array): Promise<EddsaSignature> => {
    eddsa = await buildEddsa();
    babyJub = await buildBabyjub();

    const pubKey = eddsa.prv2pub(privateKey);

    const pPubKey = babyJub.packPoint(pubKey);

    const signature = eddsa.signPedersen(privateKey, msg);

    const pSignature = eddsa.packSignature(signature);

    const msgBits = buffer2bits(msg);
    const r8Bits = buffer2bits(pSignature.slice(0, 32));
    const sBits = buffer2bits(pSignature.slice(32, 64));
    const aBits = buffer2bits(pPubKey);
    console.log("length: ", msgBits.length);

    return { A: aBits, R8: r8Bits, S: sBits, msg: msgBits };
};
